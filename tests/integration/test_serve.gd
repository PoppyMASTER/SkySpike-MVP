extends TestCase
## Service (J4.1a, refondu) : L maintenu charge le lancer, relâcher lance, saut obligatoire puis frappe en l'air ;
## prévision fidèle, serveur borné derrière la ligne, prévision sans effet sur la simulation.

const E := MatchEvent.Type


func _sim(seed_value := 1, human_server := true) -> MatchSim:
	var lineup := MatchConfig.default_lineup(SimHelpers.data().characters)
	var sim := MatchSim.new(SimHelpers.fresh_params(), seed_value, 1.0 / 120.0, lineup, -1)
	if human_server:
		sim.ctx.human_slot = sim.ctx.rally.server_slot
	return sim


func _intents(sim: MatchSim, server_intent: PlayerIntent) -> Array[PlayerIntent]:
	var out: Array[PlayerIntent] = []
	for i in sim.actors.size():
		out.append(server_intent if i == sim.ctx.rally.server_slot else PlayerIntent.make())
	return out


static func _press() -> PlayerIntent:   # appui sur L (front + maintien)
	return PlayerIntent.make(0.0, false, false, false, false, true, true)


static func _hold() -> PlayerIntent:
	return PlayerIntent.make(0.0, false, false, false, false, false, true)


## Avance jusqu'à ce que le serveur tienne le ballon (SERVE_HOLD).
func _to_hold(sim: MatchSim) -> PlayerActor:
	var server := sim.actors[sim.ctx.rally.server_slot]
	for i in 2000:
		if server.state == Enums.ActionState.SERVE_HOLD:
			return server
		sim.tick(_intents(sim, PlayerIntent.make()))
	assert_true(false, "le serveur finit par tenir le ballon")
	return server


## Appuie sur L, le maintient `ticks` ticks puis le relâche. Renvoie la vitesse du ballon juste après le lancer.
func _toss_with_hold(ticks: int, axis := 0.0) -> Vector2:
	var sim := _sim()
	var server := _to_hold(sim)
	sim.tick(_intents(sim, _press()))
	for i in ticks:
		sim.tick(_intents(sim, PlayerIntent.make(axis, false, false, false, false, false, true)))
	sim.tick(_intents(sim, PlayerIntent.make(axis)))
	assert_eq(server.state, Enums.ActionState.SERVE_TOSS, "relâcher lance le ballon")
	return sim.ball.velocity


func test_holding_longer_throws_the_ball_higher_up_to_the_maximum() -> void:
	var p := SimHelpers.fresh_params()
	var low: float = p.get_value(ParamIds.SERVE_TOSS_SPEED)
	var high: float = p.get_value(ParamIds.SERVE_TOSS_SPEED_MAX)
	var tap := _toss_with_hold(0).y
	var half := _toss_with_hold(60).y
	var full := _toss_with_hold(400).y
	assert_near(tap, low, 0.1, "appui bref : lancer bas")
	assert_true(half > tap + 0.5 and half < full - 0.5, "à mi-charge : entre les deux (%.2f)" % half)
	assert_near(full, high, 1e-3, "charge maximale plafonnée à serve_toss_speed_max")


func test_toss_curve_is_forward_by_default_and_ignores_the_direction() -> void:
	var forward: float = SimHelpers.fresh_params().get_value(ParamIds.SERVE_TOSS_FORWARD)
	var sim := _sim()
	var facing := sim.actors[sim.ctx.rally.server_slot].facing
	for axis in [-1.0, 0.0, 1.0]:
		assert_near(_toss_with_hold(10, axis).x, facing * forward, 1e-3, "avance de base vers le filet, direction tenue %s sans effet" % axis)


func test_the_serve_is_hit_in_the_air_only() -> void:
	var sim := _sim()
	var server := _to_hold(sim)
	sim.tick(_intents(sim, _press()))
	sim.tick(_intents(sim, PlayerIntent.make()))
	assert_eq(server.state, Enums.ActionState.SERVE_TOSS, "ballon lancé")
	for i in 40:   # L pendant que le serveur est au sol : rien
		sim.tick(_intents(sim, PlayerIntent.make(0.0, false, false, false, true, true, true)))
	assert_eq(server.state, Enums.ActionState.SERVE_TOSS, "pas de frappe au sol : il faut sauter")
	sim.tick(_intents(sim, PlayerIntent.make(0.0, true)))
	assert_eq(server.state, Enums.ActionState.SERVE_JUMP, "saut de service")
	sim.tick(_intents(sim, _press()))
	assert_eq(server.state, Enums.ActionState.SERVE_HIT, "frappe en l'air")


func test_l_is_a_set_outside_the_serve() -> void:
	var sim := _sim()
	var server := _to_hold(sim)
	sim.tick(_intents(sim, _press()))
	sim.tick(_intents(sim, PlayerIntent.make()))   # le ballon est lancé : la phase de jeu commence
	for i in 20:
		sim.tick(_intents(sim, PlayerIntent.make()))
	var mate := sim.actors[(server.slot + 1) % 3 + (server.slot / 3) * 3]
	assert_eq(mate.state, Enums.ActionState.FREE, "le coéquipier est libre")
	var intents := _intents(sim, PlayerIntent.make())
	intents[mate.slot] = PlayerIntent.make(0.0, false, false, false, true, true, true)   # L : passe ET service
	sim.tick(intents)
	assert_eq(mate.state, Enums.ActionState.SET, "L en jeu : une passe, jamais un service")


func test_server_never_enters_the_court_while_tossing() -> void:
	var sim := _sim()
	var server := _to_hold(sim)
	sim.tick(_intents(sim, _press()))
	sim.tick(_intents(sim, PlayerIntent.make()))
	var line := -server.facing * sim.court.half_length
	for i in 200:
		sim.tick(_intents(sim, PlayerIntent.make(float(server.facing))))
		assert_true(server.body.position.x * server.facing <= line * server.facing + 1e-6, "le serveur reste derrière la ligne de fond")
		if server.state != Enums.ActionState.SERVE_TOSS:
			break


func test_preview_arc_grows_with_the_charge() -> void:
	var sim := _sim()
	_to_hold(sim)
	sim.tick(_intents(sim, _press()))
	var early := sim.state().serve_preview
	for i in 120:
		sim.tick(_intents(sim, _hold()))
	var late := sim.state().serve_preview
	assert_true(early != null and late != null, "prévision pendant la tenue")
	if early == null or late == null:
		return
	var top_early := 0.0
	var top_late := 0.0
	for pt in early.toss_path:
		top_early = maxf(top_early, pt.y)
	for pt in late.toss_path:
		top_late = maxf(top_late, pt.y)
	assert_true(top_late > top_early + 0.8, "l'arc monte avec la charge (%.2f → %.2f m)" % [top_early, top_late])
	assert_true(late.charge > 0.9 and early.charge < 0.1, "charge affichée (%.2f → %.2f)" % [early.charge, late.charge])


func test_preview_exists_only_for_the_human_server_before_the_hit() -> void:
	var sim := _sim()
	_to_hold(sim)
	assert_true(sim.state().serve_preview != null, "prévision en tenue")
	var ai_sim := _sim(1, false)
	_to_hold(ai_sim)
	assert_true(ai_sim.state().serve_preview == null, "aucune prévision si le serveur n'est pas l'humain")


## Joue le service avec l'IA (qui n'a pas de pouvoirs spéciaux) tout en calculant la prévision du serveur.
## Renvoie la prévision à l'instant de la frappe, l'événement de contact et l'atterrissage réel.
func _ai_serve_with_preview(seed_value: int) -> Dictionary:
	var sim := _sim(seed_value)
	var ai := AiDirector.new(sim.params, seed_value, 1.0 / 120.0, -1)
	ai.set_lineup(MatchConfig.default_lineup(SimHelpers.data().characters))
	var server := sim.actors[sim.ctx.rally.server_slot]
	var preview: ServePreview
	var contact: MatchEvent
	var landing := NAN
	for i in 3000:
		var state := sim.state()
		var intents := ai.intents(state)
		if server.state == Enums.ActionState.SERVE_JUMP and intents[server.slot].serve_pressed and preview == null:
			preview = state.serve_preview
		for e in sim.tick(intents):
			if e.type == E.CONTACT and contact == null:
				contact = e
			if e.type == E.BALL_LANDED and is_nan(landing):
				landing = e.details.x
		if not is_nan(landing):
			break
	return {"preview": preview, "contact": contact, "landing": landing}


func test_preview_predicts_the_real_serve() -> void:
	for seed_value in [1, 2, 3, 4]:
		var r := _ai_serve_with_preview(seed_value)
		var pv: ServePreview = r.preview
		assert_true(pv != null and pv.can_hit and not pv.planned, "graine %d : une frappe est prévue en l'air" % seed_value)
		if pv == null or r.contact == null:
			continue
		assert_near(r.contact.details.q, pv.quality, 0.2, "graine %d : qualité prévue" % seed_value)
		var spread := pv.landing_max - pv.landing_min
		assert_true(r.landing >= pv.landing_min - spread - 0.8 and r.landing <= pv.landing_max + spread + 0.8,
			"graine %d : atterrissage réel %.2f dans la zone prévue [%.2f ; %.2f]" % [seed_value, r.landing, pv.landing_min, pv.landing_max])


func test_depth_follows_the_held_direction_and_clears_the_net() -> void:
	var sim := _sim()
	var server := sim.actors[sim.ctx.rally.server_slot]
	var spec := ContactSpec.of(ContactSpec.SERVE, sim.params)
	var from := Vector2(-server.facing * 9.15, 2.1)
	var reach := {}
	for aim in [-1.0, 0.0, 1.0]:
		var plan := ContactResolver.plan_contact(spec, server, sim.ctx, from, spec.ideal, 0.0, aim, 0.0)
		var flight := ServePreview._fly(sim.ctx, from, plan.speed, plan.angle, server.facing, false)
		assert_true(flight.clears, "visée %s : passe le filet" % aim)
		reach[aim] = absf(flight.x)
	assert_true(reach[1.0] > reach[0.0] + 1.5 and reach[0.0] > reach[-1.0] + 1.5, "profondeur croissante avec la direction vers l'avant : %s" % reach)
	assert_near(reach[-1.0], 9.0 * sim.params.get_value(ParamIds.ASSIST_RATIO_MIN), 0.4, "court = ratio mini")
	assert_near(reach[1.0], 9.0 * sim.params.get_value(ParamIds.ASSIST_RATIO_MAX), 0.4, "long = ratio maxi")


func test_state_reads_do_not_change_the_simulation() -> void:
	var a := _sim(5)
	var b := _sim(5)
	for i in 1500:
		var press := _press() if i % 150 == 0 else (_hold() if i % 150 < 40 else PlayerIntent.make(0.0, i % 150 == 90))
		a.tick(_intents(a, press))
		a.state()
		a.state()   # prévisions recalculées plusieurs fois par tick
		b.tick(_intents(b, press))
	assert_eq(a.state().fingerprint(), b.state().fingerprint(), "même empreinte avec et sans lecture de la prévision")


func test_missed_serve_does_not_freeze_the_server() -> void:
	var sim := _sim(4)
	var server := _to_hold(sim)
	sim.tick(_intents(sim, _press()))
	sim.tick(_intents(sim, PlayerIntent.make()))   # lancé, puis plus rien : le ballon retombe
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


func test_ball_prediction_is_published_while_the_ball_flies() -> void:
	var sim := _sim()
	_to_hold(sim)
	assert_true(sim.state().ball_prediction == null, "ballon tenu : pas de prévision de balle")
	sim.tick(_intents(sim, _press()))
	sim.tick(_intents(sim, PlayerIntent.make()))
	var pred := sim.state().ball_prediction
	assert_true(pred != null and pred.path.size() > 10, "ballon en vol : trajectoire prévue")
	if pred != null:
		assert_true(absf(pred.landing_x) < 12.0, "atterrissage prévu au sol près du serveur (%.2f)" % pred.landing_x)
