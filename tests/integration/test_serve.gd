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


func test_tap_gives_a_low_toss() -> void:
	var p := SimHelpers.fresh_params()
	var v := _toss_with_hold(0)
	assert_near(v.y, p.get_value(ParamIds.SERVE_TOSS_LOW_SPEED), 1e-3, "appui bref : lancer bas")
	assert_near(absf(v.x), p.get_value(ParamIds.SERVE_TOSS_FORWARD_MIN), 1e-3, "appui bref : avance minimale")


func test_holding_longer_throws_the_ball_higher_and_forward_up_to_the_maximum() -> void:
	var p := SimHelpers.fresh_params()
	var tap_ticks := int(ceil(p.get_value(ParamIds.SERVE_TAP_MAX_S) * 120.0)) + 1
	var start := _toss_with_hold(tap_ticks)
	var half := _toss_with_hold(tap_ticks + 60)
	var full := _toss_with_hold(tap_ticks + 400)
	assert_near(start.y, p.get_value(ParamIds.SERVE_TOSS_SPEED), 0.15, "juste après le seuil : début de la charge")
	assert_true(half.y > start.y + 0.5 and half.y < full.y - 0.5, "à mi-charge : entre les deux (%.2f)" % half.y)
	assert_near(full.y, p.get_value(ParamIds.SERVE_TOSS_SPEED_MAX), 1e-3, "charge maximale plafonnée à serve_toss_speed_max")
	assert_true(absf(half.x) > absf(start.x) and absf(full.x) > absf(half.x), "plus la charge est longue, plus le lancer avance")
	assert_near(absf(full.x), p.get_value(ParamIds.SERVE_TOSS_FORWARD), 1e-3, "avance maximale = serve_toss_forward")


func test_direction_held_does_not_change_the_toss() -> void:
	var ref := _toss_with_hold(40, 0.0)
	for axis in [-1.0, 1.0]:
		assert_eq(_toss_with_hold(40, axis), ref, "direction tenue %s sans effet sur le lancer" % axis)


func test_release_is_needed_to_toss_and_cancel_keeps_the_ball() -> void:
	var sim := _sim()
	var server := _to_hold(sim)
	sim.tick(_intents(sim, _press()))
	for i in 100:
		sim.tick(_intents(sim, _hold()))
	assert_eq(server.state, Enums.ActionState.SERVE_HOLD, "tant que L est maintenu, le ballon reste tenu")
	sim.tick(_intents(sim, PlayerIntent.make(0.0, false, true, false, false, false, true)))   # K : annulation
	assert_eq(server.state, Enums.ActionState.SERVE_HOLD, "annulation : toujours en tenue")
	sim.tick(_intents(sim, PlayerIntent.make()))   # relâché après l'annulation : pas de lancer
	assert_eq(server.state, Enums.ActionState.SERVE_HOLD, "relâcher après annulation ne lance rien")
	sim.tick(_intents(sim, _press()))
	sim.tick(_intents(sim, PlayerIntent.make()))
	assert_eq(server.state, Enums.ActionState.SERVE_TOSS, "un nouvel appui puis relâché lance")


func test_held_press_from_before_does_not_toss() -> void:
	# L déjà maintenu quand le ballon est remis : sans front d'appui, rien ne se passe.
	var sim := _sim()
	var server := _to_hold(sim)
	for i in 30:
		sim.tick(_intents(sim, _hold()))
	assert_eq(server.state, Enums.ActionState.SERVE_HOLD, "un maintien sans front d'appui ne déclenche rien")


func test_toss_press_cannot_also_hit_the_ball() -> void:
	var sim := _sim()
	var server := _to_hold(sim)
	sim.tick(_intents(sim, _press()))
	sim.tick(_intents(sim, PlayerIntent.make()))
	var lockout := int(sim.params.get_value(ParamIds.SERVE_LOCKOUT_S) * 120.0)
	for i in maxi(lockout - 2, 1):
		sim.tick(_intents(sim, _press()))   # appuis pendant le verrou
		assert_eq(server.state, Enums.ActionState.SERVE_TOSS, "verrou anti double appui")
	for i in 5:
		sim.tick(_intents(sim, PlayerIntent.make()))
	sim.tick(_intents(sim, _press()))
	assert_eq(server.state, Enums.ActionState.SERVE_HIT, "après le verrou, L frappe au sol")


## Lance (appui bref ou charge), puis renvoie le serveur et le simulateur pour la suite.
func _tossed(hold_ticks := 0, seed_value := 1) -> Array:
	var sim := _sim(seed_value)
	var server := _to_hold(sim)
	sim.tick(_intents(sim, _press()))
	for i in hold_ticks:
		sim.tick(_intents(sim, _hold()))
	sim.tick(_intents(sim, PlayerIntent.make()))
	return [sim, server]


## Joue jusqu'au contact de service ; `strike` renvoie l'intention à chaque tick. Renvoie l'événement CONTACT.
func _play_until_contact(sim: MatchSim, strike: Callable, max_ticks := 400) -> MatchEvent:
	for i in max_ticks:
		for e in sim.tick(_intents(sim, strike.call(i))):
			if e.type == E.CONTACT and e.details.action == "serve":
				return e
	return null


func test_ground_serve_after_a_short_toss() -> void:
	var r := _tossed(0)
	var sim: MatchSim = r[0]
	var server: PlayerActor = r[1]
	# L quand le ballon passe dans la zone (≈ 0,45 s après le lancer) : frappe au sol.
	var contact := _play_until_contact(sim, func(i: int) -> PlayerIntent:
		return _press() if i == 40 else PlayerIntent.make())
	assert_true(contact != null, "le service au sol touche le ballon")
	if contact == null:
		return
	assert_eq(contact.details.serve_kind, "ground", "type de service : au sol")
	assert_true(server.body.grounded, "le serveur n'a pas quitté le sol")
	var top := StatConversion.serve_speed(server.character.stats, sim.params) * sim.params.get_value(ParamIds.SERVE_GROUND_SPEED_MULT)
	assert_true(contact.details.speed <= top + 1e-3, "vitesse du service au sol plafonnée (%.2f ≤ %.2f)" % [contact.details.speed, top])


func test_jump_serve_with_space_then_space_or_l_shares_one_contact() -> void:
	for use_l in [false, true]:
		var r := _tossed(150)   # lancer haut
		var sim: MatchSim = r[0]
		var server: PlayerActor = r[1]
		var contacts := 0
		var hit_state_ticks := 0
		for i in 400:
			var jump := i == 12
			var strike := i >= 30   # appui maintenu pendant plusieurs ticks : un seul contact
			var intent: PlayerIntent
			if strike and use_l:
				intent = _press()
			elif strike:
				intent = PlayerIntent.make(0.0, true)
			else:
				intent = PlayerIntent.make(0.0, jump)
			for e in sim.tick(_intents(sim, intent)):
				if e.type == E.CONTACT and e.details.action == "serve":
					contacts += 1
					assert_true(e.details.serve_kind in ["float", "smash"], "frappe sautée : flottant ou smash (%s)" % e.details.serve_kind)
			if server.state == Enums.ActionState.SERVE_HIT:
				hit_state_ticks += 1
		assert_true(contacts <= 1, "une seule logique de contact (%d contacts, L=%s)" % [contacts, use_l])


func test_smash_serve_speed_is_capped_by_its_own_parameter() -> void:
	var r := _tossed(150)
	var sim: MatchSim = r[0]
	sim.params.set_value(ParamIds.SERVE_SMASH_SPEED_CAP, 11.0)
	sim.params.set_value(ParamIds.SERVE_SMASH_JUMP_RATIO, 0.3)
	var contact: MatchEvent
	for i in 400:
		var intent := PlayerIntent.make(0.0, i == 12)
		if i == 40:
			intent = _press()
		for e in sim.tick(_intents(sim, intent)):
			if e.type == E.CONTACT and e.details.action == "serve" and contact == null:
				contact = e
	assert_true(contact != null, "le service sauté touche le ballon")
	if contact != null:
		assert_true(contact.details.speed <= 11.0 + 1e-3, "plafond de vitesse du smash respecté (%.2f)" % contact.details.speed)


func test_serve_kind_depends_on_the_height_of_the_jump() -> void:
	var sim := _sim()
	var server := sim.actors[sim.ctx.rally.server_slot]
	var apex := StatConversion.jump_apex(server.character.stats, sim.params)
	assert_eq(ContactResolver.serve_kind(server, sim.params, 0.0), ContactResolver.SERVE_GROUND, "au sol")
	assert_eq(ContactResolver.serve_kind(server, sim.params, apex * 0.4), ContactResolver.SERVE_FLOAT, "petit saut : flottant")
	assert_eq(ContactResolver.serve_kind(server, sim.params, apex * 0.95), ContactResolver.SERVE_SMASH, "saut haut : smash")


func test_missed_strike_gives_no_contact() -> void:
	var r := _tossed(0)
	var sim: MatchSim = r[0]
	var contact := _play_until_contact(sim, func(i: int) -> PlayerIntent:
		return _press() if i == 150 else PlayerIntent.make(), 300)   # trop tard : le ballon est retombé
	assert_true(contact == null, "frappe trop tardive : pas de contact")


func test_toss_moves_with_the_server_before_the_toss_only_through_the_hold_position() -> void:
	# Le ballon part de la position de tenue ; la trajectoire réelle suit la parabole annoncée (même physique).
	var sim := _sim()
	var server := _to_hold(sim)
	sim.tick(_intents(sim, _press()))
	for i in 80:
		sim.tick(_intents(sim, _hold()))
	var path := sim.state().serve_preview.toss_path
	sim.tick(_intents(sim, PlayerIntent.make()))
	var real := PackedVector2Array()
	for i in 120:
		real.append(sim.ball.position)
		sim.tick(_intents(sim, PlayerIntent.make()))
	var worst := 0.0
	for k in path.size():
		var idx := k * ServePreview.SAMPLE_EVERY_TOSS
		if idx < real.size():
			worst = maxf(worst, path[k].distance_to(real[idx]))
	assert_true(worst < 0.15, "la balle suit la trajectoire annoncée (écart max %.3f m)" % worst)


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
	for i in 160:
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
	sim.params.set_value(ParamIds.AI_SERVE_GROUND_CHANCE, 0.0)   # service sauté : c'est lui que la prévision décrit
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
	var rise := StatConversion.jump_apex(server.character.stats, sim.params)   # frappe au sommet du saut
	var reach := {}
	for aim in [-1.0, 0.0, 1.0]:
		var plan := ContactResolver.plan_contact(spec, server, sim.ctx, from, spec.ideal, 0.0, aim, 0.0, rise)
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


func test_ai_serves_on_the_ground_or_in_the_air_with_the_same_mechanisms() -> void:
	var kinds := {}
	for seed_value in range(1, 13):
		var sim := _sim(seed_value, false)
		var ai := AiDirector.new(sim.params, seed_value, 1.0 / 120.0, -1)
		ai.set_lineup(MatchConfig.default_lineup(SimHelpers.data().characters))
		var fault := false
		for i in 2500:
			for e in sim.tick(ai.intents(sim.state())):
				if e.type == E.CONTACT and e.details.action == "serve":
					kinds[e.details.serve_kind] = int(kinds.get(e.details.serve_kind, 0)) + 1
					i = 99999
				elif e.type == E.FAULT:
					fault = true
			if i >= 99999:
				break
		assert_true(not fault, "graine %d : service IA sans faute" % seed_value)
	assert_true(kinds.has("ground") and (kinds.has("float") or kinds.has("smash")), "l'IA varie ses services : %s" % kinds)
