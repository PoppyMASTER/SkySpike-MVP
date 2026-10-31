extends TestCase
## Service refondu (J4.1a) : lancer contrôlé par la direction tenue, prévisualisation fidèle,
## serveur borné derrière la ligne, prévision sans effet sur la simulation.

const E := MatchEvent.Type


func _sim(seed_value := 1, human_server := true) -> MatchSim:
	var lineup := MatchConfig.default_lineup(SimHelpers.data().characters)
	var sim := MatchSim.new(SimHelpers.fresh_params(), seed_value, 1.0 / 120.0, lineup, -1)
	if human_server:
		sim.ctx.human_slot = sim.ctx.rally.server_slot
	return sim


func _intents(sim: MatchSim, slot_intent: PlayerIntent) -> Array[PlayerIntent]:
	var out: Array[PlayerIntent] = []
	for i in sim.actors.size():
		out.append(slot_intent if i == sim.ctx.rally.server_slot else PlayerIntent.make())
	return out


## Avance jusqu'à ce que le serveur tienne le ballon (SERVE_HOLD).
func _to_hold(sim: MatchSim) -> PlayerActor:
	var server := sim.actors[sim.ctx.rally.server_slot]
	for i in 2000:
		if server.state == Enums.ActionState.SERVE_HOLD:
			return server
		sim.tick(_intents(sim, PlayerIntent.make()))
	assert_true(false, "le serveur finit par tenir le ballon")
	return server


func _toss_velocity_x(axis: float) -> float:
	var sim := _sim()
	var server := _to_hold(sim)
	sim.tick(_intents(sim, PlayerIntent.make(axis, false, false, false, false, true)))
	assert_eq(server.state, Enums.ActionState.SERVE_TOSS, "le ballon est lancé")
	return sim.ball.velocity.x


func test_toss_drift_follows_the_held_direction() -> void:
	var drift: float = SimHelpers.fresh_params().get_value(ParamIds.SERVE_TOSS_DRIFT)
	assert_near(_toss_velocity_x(0.0), 0.0, 1e-6, "direction neutre : lancer droit")
	assert_near(_toss_velocity_x(1.0), drift, 1e-3, "droite tenue : dérive vers la droite")
	assert_near(_toss_velocity_x(-1.0), -drift, 1e-3, "gauche tenue : dérive vers la gauche")
	assert_near(_toss_velocity_x(0.5), drift * 0.5, 1e-3, "dérive proportionnelle à la direction")


func test_server_never_enters_the_court_while_tossing() -> void:
	var sim := _sim()
	var server := _to_hold(sim)
	sim.tick(_intents(sim, PlayerIntent.make(1.0, false, false, false, false, true)))
	var line := -server.facing * sim.court.half_length
	for i in 200:
		sim.tick(_intents(sim, PlayerIntent.make(float(server.facing))))
		assert_true(server.body.position.x * server.facing <= line * server.facing + 1e-6, "le serveur reste derrière la ligne de fond")
		if server.state != Enums.ActionState.SERVE_TOSS:
			break


func test_server_can_step_under_the_ball_during_the_toss() -> void:
	var sim := _sim()
	var server := _to_hold(sim)
	var x0 := server.body.position.x
	sim.tick(_intents(sim, PlayerIntent.make(-float(server.facing), false, false, false, false, true)))
	for i in 30:
		sim.tick(_intents(sim, PlayerIntent.make(-float(server.facing))))
	var moved := absf(server.body.position.x - x0)
	var run_speed := StatConversion.run_speed(server.character.stats, sim.params)
	assert_true(moved > 0.05, "déplacement permis pendant le lancer (%.2f m)" % moved)
	assert_true(moved < run_speed * 0.25 * sim.params.get_value(ParamIds.SERVE_TOSS_MOVE_FACTOR) + 0.05, "mais plus lent que la course (%.2f m)" % moved)


func test_preview_exists_only_for_the_human_server_before_the_hit() -> void:
	var sim := _sim()
	var server := _to_hold(sim)
	assert_true(sim.state().serve_preview != null, "prévision en tenue")
	assert_true(sim.state().serve_preview.holding, "…marquée « en tenue »")
	sim.tick(_intents(sim, PlayerIntent.make(0.0, false, false, false, false, true)))
	assert_true(sim.state().serve_preview != null and not sim.state().serve_preview.holding, "prévision pendant le lancer")
	var ai_sim := _sim(1, false)
	_to_hold(ai_sim)
	assert_true(ai_sim.state().serve_preview == null, "aucune prévision si le serveur n'est pas l'humain")
	var done := false
	for i in 600:
		var press := server.state == Enums.ActionState.SERVE_TOSS and i == 70
		sim.tick(_intents(sim, PlayerIntent.make(0.0, false, false, false, false, press)))
		if sim.ctx.rally.served:
			done = true
			break
	assert_true(done, "le service est frappé")
	assert_true(sim.state().serve_preview == null, "plus de prévision une fois le service frappé")


func test_hold_preview_follows_the_held_direction() -> void:
	var sim := _sim()
	var server := _to_hold(sim)
	sim.tick(_intents(sim, PlayerIntent.make(1.0)))
	var right := sim.state().serve_preview
	sim.tick(_intents(sim, PlayerIntent.make(-1.0)))
	var left := sim.state().serve_preview
	assert_true(right != null and left != null and right.toss_path.size() > 3, "arc de lancer prévu")
	assert_true(right.toss_path[3].x > left.toss_path[3].x, "l'arc suit la direction tenue (%s / %s)" % [right.toss_path[3], left.toss_path[3]])
	assert_near(right.toss_path[0].x, left.toss_path[0].x, 1e-6, "même point de départ : la main du serveur")
	assert_true(server.state == Enums.ActionState.SERVE_HOLD, "rien n'est lancé tant qu'on ne frappe pas L")


## Frappe réelle à partir d'un lancer : renvoie {preview, quality, landing_x}.
func _real_serve(seed_value: int, aim: float, press_tick: int) -> Dictionary:
	var sim := _sim(seed_value)
	var server := _to_hold(sim)
	sim.tick(_intents(sim, PlayerIntent.make(0.0, false, false, false, false, true)))
	var preview: ServePreview
	var contact: MatchEvent
	var landing := NAN
	for i in 900:
		var press := i == press_tick
		if i == press_tick - 1:
			preview = sim.state().serve_preview
		var axis := aim if i >= press_tick - 1 else 0.0   # on ne tient la visée qu'à la frappe
		for e in sim.tick(_intents(sim, PlayerIntent.make(axis, false, false, false, false, press))):
			if e.type == E.CONTACT and contact == null:
				contact = e
			if e.type == E.BALL_LANDED and is_nan(landing):
				landing = e.details.x
		if not is_nan(landing):
			break
	return {"preview": preview, "contact": contact, "landing": landing, "server": server}


func test_preview_predicts_the_real_serve() -> void:
	for seed_value in [1, 2, 3]:
		for aim in [-1.0, 0.0, 1.0]:
			var r := _real_serve(seed_value, aim, 108)
			var pv: ServePreview = r.preview
			assert_true(pv != null and pv.can_hit, "graine %d visée %s : une frappe est prévue" % [seed_value, aim])
			if pv == null or r.contact == null:
				continue
			assert_near(r.contact.details.q, pv.quality, 0.1 if aim == 0.0 else 0.2, "graine %d visée %s : qualité prévue" % [seed_value, aim])
			var spread := pv.landing_max - pv.landing_min
			assert_true(r.landing >= pv.landing_min - spread - 0.6 and r.landing <= pv.landing_max + spread + 0.6,
				"graine %d visée %s : atterrissage réel %.2f dans la zone prévue [%.2f ; %.2f]" % [seed_value, aim, r.landing, pv.landing_min, pv.landing_max])


func test_preview_depth_changes_with_the_held_direction() -> void:
	var sim := _sim()
	_to_hold(sim)
	sim.tick(_intents(sim, PlayerIntent.make(0.0, false, false, false, false, true)))
	for i in 107:
		sim.tick(_intents(sim, PlayerIntent.make(0.0)))
	var facing := sim.actors[sim.ctx.rally.server_slot].facing
	sim.tick(_intents(sim, PlayerIntent.make(float(facing))))
	var long_pv := sim.state().serve_preview
	sim.tick(_intents(sim, PlayerIntent.make(-float(facing))))
	var short_pv := sim.state().serve_preview
	assert_true(long_pv != null and short_pv != null and long_pv.can_hit and short_pv.can_hit, "deux prévisions")
	if long_pv != null and short_pv != null:
		assert_true(absf(long_pv.landing_x) > absf(short_pv.landing_x) + 2.0, "vers l'avant : nettement plus long (%.2f contre %.2f)" % [long_pv.landing_x, short_pv.landing_x])
		assert_true(long_pv.lands_in and short_pv.lands_in, "les deux services passent le filet et tombent dans le camp adverse")
		assert_true(long_pv.landing_x * facing > 0.0 and short_pv.landing_x * facing > 0.0, "dans le camp adverse")


func test_preview_does_not_change_the_simulation() -> void:
	var with_preview := _sim(5)
	var without := _sim(5)
	for i in 1500:
		var a_intents := _intents(with_preview, PlayerIntent.make(1.0 if i % 90 < 45 else -1.0, false, false, false, false, i % 70 == 0))
		var b_intents := _intents(without, PlayerIntent.make(1.0 if i % 90 < 45 else -1.0, false, false, false, false, i % 70 == 0))
		with_preview.tick(a_intents)
		with_preview.state()   # calcule la prévision à chaque tick
		without.tick(b_intents)
	assert_eq(with_preview.state().fingerprint(), without.state().fingerprint(), "même empreinte avec et sans prévision")


func test_missed_serve_does_not_freeze_the_server() -> void:
	var sim := _sim(4)
	var server := _to_hold(sim)
	sim.tick(_intents(sim, PlayerIntent.make(0.0, false, false, false, false, true)))   # lancer, puis plus rien
	var next_serve := false
	var previous := sim.ctx.rally.phase
	for i in 3000:
		sim.tick(_intents(sim, PlayerIntent.make()))
		var phase := sim.ctx.rally.phase
		if phase == Enums.Phase.SERVE_PREP and previous != Enums.Phase.SERVE_PREP and sim.ctx.rally.score[1] == 1:
			next_serve = true
			break
		previous = phase
	assert_true(next_serve, "après un service raté, un nouveau service démarre (phase %s)" % Enums.phase_to_string(sim.ctx.rally.phase))
	assert_eq(sim.ctx.rally.serving_team, 1, "faute de service : le service passe à l'adversaire")
	assert_true(server.state != Enums.ActionState.SERVE_TOSS, "le serveur n'est plus figé dans le lancer")
