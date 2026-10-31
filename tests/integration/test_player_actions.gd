extends TestCase
## Le joueur dans la simulation : course, saut, réception, smash, filet, réglages en direct.

const E := MatchEvent.Type


func test_player_stops_at_the_net_and_at_the_back_margin() -> void:
	var sim := SimHelpers.make_sim()
	SimHelpers.park_ball(sim)
	var right := PlayerIntent.make(1.0)
	for i in 400:
		SimHelpers.one_tick(sim, right)
		SimHelpers.park_ball(sim)
		assert_true(sim.actors[0].body.position.x <= -0.3 + 1e-6, "jamais de l'autre côté du filet")
	assert_near(sim.actors[0].body.position.x, -(0.05 + 0.25), 1e-6, "collé au filet (demi-épaisseur + demi-largeur)")
	for i in 600:
		SimHelpers.one_tick(sim, PlayerIntent.make(-1.0))
		SimHelpers.park_ball(sim)
	assert_near(sim.actors[0].body.position.x, -12.0, 1e-6, "limite arrière = ligne de fond + marge")


func test_jump_reaches_the_stat_height_then_lands_and_recovers() -> void:
	var sim := SimHelpers.make_sim("std_attacker_01")
	SimHelpers.park_ball(sim)
	var apex_expected := StatConversion.jump_apex(SimHelpers.data().characters.get_character("std_attacker_01").stats, sim.params)
	var events := SimHelpers.one_tick(sim, PlayerIntent.make(0.0, true))
	assert_eq(SimHelpers.count_type(events, E.PLAYER_JUMPED), 1, "saut signalé")
	assert_eq(sim.actors[0].state, Enums.ActionState.AIR, "état en l'air")
	var peak := 0.0
	var landed := false
	for i in 200:
		SimHelpers.park_ball(sim)
		var ev := SimHelpers.one_tick(sim)
		peak = maxf(peak, sim.actors[0].body.position.y)
		if SimHelpers.count_type(ev, E.PLAYER_LANDED) > 0:
			landed = true
			assert_eq(sim.actors[0].state, Enums.ActionState.RECOVER, "récupération juste après l'atterrissage")
			break
	assert_true(landed, "atterrit")
	assert_near(peak, apex_expected, 0.01, "hauteur = stat de saut convertie")
	for i in 20:
		SimHelpers.park_ball(sim)
		SimHelpers.one_tick(sim)
	assert_eq(sim.actors[0].state, Enums.ActionState.FREE, "libre après la récupération")


func test_receive_hits_the_ball_forward_and_up_once() -> void:
	var sim := SimHelpers.make_sim()
	SimHelpers.one_tick(sim, PlayerIntent.make(0.0, false, true))
	SimHelpers.put_ball_in_zone(sim, true, Vector2(0, 0.1))
	var events := SimHelpers.run(sim, 60)
	var contact := SimHelpers.first_of(events, E.CONTACT)
	assert_true(contact != null, "contact produit")
	assert_eq(SimHelpers.count_type(events, E.CONTACT), 1, "un seul contact par action")
	assert_eq(contact.details.action, "receive", "c'est une réception")
	assert_true(contact.details.q > 0.5, "ballon dans la zone, bon moment : bonne qualité (%s)" % contact.details.q)
	assert_true(sim.ball.velocity.x > 0.0, "renvoyé vers le filet")
	assert_true(sim.ball.velocity.y > 0.0 or sim.ball.position.y < 3.0, "renvoyé vers le haut")
	assert_eq(sim.actors[0].state == Enums.ActionState.RECEIVE, false, "fenêtre refermée après le contact")


func test_receive_without_ball_is_missed_then_recovers() -> void:
	var sim := SimHelpers.make_sim()
	SimHelpers.park_ball(sim)
	var events := SimHelpers.one_tick(sim, PlayerIntent.make(0.0, false, true))
	for i in 80:
		SimHelpers.park_ball(sim)
		events.append_array(SimHelpers.one_tick(sim))
	assert_eq(SimHelpers.count_type(events, E.ACTION_MISSED), 1, "action ratée signalée")
	assert_eq(SimHelpers.count_type(events, E.CONTACT), 0, "aucun contact")
	assert_eq(sim.actors[0].state, Enums.ActionState.FREE, "retour à l'état libre")


func test_ball_outside_the_zone_is_not_touched() -> void:
	var sim := SimHelpers.make_sim()
	SimHelpers.one_tick(sim, PlayerIntent.make(0.0, false, true))
	SimHelpers.put_ball_in_zone(sim, true, Vector2(0, 2.0))   # bien au-dessus (rayon 0,6)
	var events := SimHelpers.run(sim, 40)
	assert_eq(SimHelpers.count_type(events, E.CONTACT), 0, "hors zone : pas de contact")


func test_timing_changes_quality_angle_and_speed() -> void:
	var early := _receive_after(0)
	var ideal := _receive_after(int(round(0.14 * 120.0)))
	assert_true(early.details.e_t < ideal.details.e_t, "trop tôt : erreur de temps négative")
	assert_true(early.details.q < ideal.details.q, "qualité plus faible trop tôt")
	assert_true(early.details.angle > ideal.details.angle, "trop tôt = plus haut (même tirage de bruit)")
	assert_true(early.details.speed < ideal.details.speed, "trop tôt = moins rapide")


## Réception dont le ballon n'entre dans la zone qu'après `wait` ticks (graine identique → même bruit).
func _receive_after(wait: int) -> MatchEvent:
	var sim := SimHelpers.make_sim("std_attacker_01", 3)
	SimHelpers.one_tick(sim, PlayerIntent.make(0.0, false, true))
	for i in wait:
		SimHelpers.park_ball(sim)
		SimHelpers.one_tick(sim)
	SimHelpers.put_ball_in_zone(sim, true)
	return SimHelpers.first_of(SimHelpers.run(sim, 60), E.CONTACT)


func test_spike_needs_a_jump_and_only_once_per_jump() -> void:
	var params := SimHelpers.fresh_params()
	params.set_value(ParamIds.AIM_MODE, 0.0)   # visée manuelle : l'angle ne dépend que du timing
	var sim := SimHelpers.make_sim("hammer_01", 1, 1.0 / 120.0, params, 0)
	SimHelpers.park_ball(sim)
	var events := SimHelpers.one_tick(sim, PlayerIntent.make(0.0, true))
	for i in 15:
		SimHelpers.park_ball(sim)
		SimHelpers.one_tick(sim)
	events = SimHelpers.one_tick(sim, PlayerIntent.make(0.0, true))
	assert_eq(SimHelpers.count_type(events, E.ACTION_STARTED), 1, "smash engagé en l'air")
	assert_eq(sim.actors[0].state, Enums.ActionState.SPIKE, "état smash")
	SimHelpers.put_ball_in_zone(sim, false)
	var contact: MatchEvent = null
	for i in 40:
		contact = SimHelpers.first_of(SimHelpers.one_tick(sim), E.CONTACT)
		if contact != null:
			break
	assert_true(contact != null and contact.details.action == "spike", "contact de smash")
	assert_true(sim.ball.velocity.x > 0.0 and sim.ball.velocity.y < 0.0, "smash vers l'avant et vers le bas : %s" % sim.ball.velocity)
	assert_true(sim.ball.velocity.length() > 20.0, "smash rapide")
	events = SimHelpers.one_tick(sim, PlayerIntent.make(0.0, true))
	assert_eq(SimHelpers.count_type(events, E.ACTION_STARTED), 0, "pas de second smash pendant le même saut")


func test_receive_is_ignored_in_the_air_and_during_recovery() -> void:
	var sim := SimHelpers.make_sim()
	SimHelpers.park_ball(sim)
	SimHelpers.one_tick(sim, PlayerIntent.make(0.0, true))
	var events := SimHelpers.one_tick(sim, PlayerIntent.make(0.0, false, true))
	var started := SimHelpers.first_of(events, E.ACTION_STARTED)
	assert_true(started == null or started.details.action != "receive", "pas de réception en l'air (en l'air, la touche feinte)")


func test_ball_cannot_tunnel_through_the_net_even_at_low_tick_rates() -> void:
	for hz in [60.0, 120.0, 240.0]:
		var sim := SimHelpers.make_sim("", 1, 1.0 / hz)
		sim.place_ball(Vector2(-1.0, 1.2), Vector2(60.0, 0.0))
		var hit := false
		for i in int(hz):
			for e in sim.tick():
				if e.type == E.NET_HIT:
					hit = true
			if hit:
				break
			assert_true(sim.ball.position.x < 0.0, "%d Hz : toujours du côté gauche avant le contact" % hz)
		assert_true(hit, "%d Hz : filet touché" % hz)
		assert_true(sim.ball.velocity.x < 0.0, "%d Hz : le ballon repart vers la gauche" % hz)
		assert_near(absf(sim.ball.velocity.x), 60.0 * 0.35, 0.01, "%d Hz : rebond × restitution" % hz)


func test_ball_bounces_up_off_the_net_tape() -> void:
	var sim := SimHelpers.make_sim("")
	sim.place_ball(Vector2(0.0, 3.0), Vector2(0.0, -8.0))
	var events := SimHelpers.run(sim, 30)
	var hit := SimHelpers.first_of(events, E.NET_HIT)
	assert_true(hit != null, "bord supérieur touché")
	assert_eq(hit.details.ny, 1.0, "normale vers le haut")
	assert_true(sim.ball.velocity.y > -8.0, "le ballon a rebondi")


func test_settings_apply_live_without_restart() -> void:
	var sim := SimHelpers.make_sim("std_attacker_01")
	SimHelpers.park_ball(sim)
	SimHelpers.run(sim, 6, PlayerIntent.make(1.0))
	var slow := sim.actors[0].body.velocity.x
	var sim2 := SimHelpers.make_sim("std_attacker_01")
	sim2.params.set_value(ParamIds.GROUND_ACCEL, 100.0)
	SimHelpers.park_ball(sim2)
	SimHelpers.run(sim2, 6, PlayerIntent.make(1.0))
	assert_true(sim2.actors[0].body.velocity.x > slow, "accélération plus forte → plus rapide au même tick")
	# Changer le paramètre en cours de route agit au tick suivant.
	sim.params.set_value(ParamIds.GROUND_ACCEL, 100.0)
	var before := sim.actors[0].body.velocity.x
	SimHelpers.park_ball(sim)
	SimHelpers.one_tick(sim, PlayerIntent.make(1.0))
	assert_near(sim.actors[0].body.velocity.x - before, 100.0 / 120.0, 1e-6, "nouvelle accélération prise en compte immédiatement")


func test_court_dimensions_apply_to_the_next_match_only() -> void:
	var params := SimHelpers.fresh_params()
	var sim := SimHelpers.make_sim("", 1, 1.0 / 120.0, params)
	params.set_value(ParamIds.NET_HEIGHT, 2.6)
	assert_near(sim.state().net_height, 2.43, 1e-9, "match en cours inchangé")
	var next := SimHelpers.make_sim("", 1, 1.0 / 120.0, params)
	assert_near(next.state().net_height, 2.6, 1e-9, "le match suivant utilise la nouvelle hauteur")
