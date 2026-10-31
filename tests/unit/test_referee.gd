extends TestCase
## Règles du volley : touches, fautes, atterrissages, points, rotation, fin de partie.

const E := MatchEvent.Type


func _match() -> MatchSim:
	var lineup := MatchConfig.default_lineup(SimHelpers.data().characters)
	return MatchSim.new(SimHelpers.fresh_params(), 1, 1.0 / 120.0, lineup, -1)


func _touch(sim: MatchSim, slot: int, block := false, kind := "receive") -> bool:
	return sim.referee.register_contact({"slot": slot, "block": block, "kind": kind})


func test_match_starts_ready_with_six_players_and_zero_score() -> void:
	var sim := _match()
	assert_eq(sim.actors.size(), 6, "six joueurs")
	assert_eq(sim.ctx.rally.phase, Enums.Phase.READY, "phase initiale")
	assert_eq(sim.ctx.rally.score, [0, 0] as Array[int], "score nul")
	assert_eq(sim.actors[0].team, 0, "slots 0-2 : équipe bleue")
	assert_eq(sim.actors[5].team, 1, "slots 3-5 : équipe rouge")


func test_three_touches_allowed_fourth_is_a_fault() -> void:
	var sim := _match()
	sim.ctx.rally.served = true
	assert_false(_touch(sim, 3), "touche 1")
	assert_false(_touch(sim, 4), "touche 2")
	assert_false(_touch(sim, 5), "touche 3")
	assert_true(_touch(sim, 3), "touche 4 : faute")
	assert_eq(sim.ctx.rally.fault_text, "too_many_touches", "motif")
	assert_eq(sim.ctx.rally.score[0], 1, "le point va à l'adversaire")


func test_same_player_twice_in_a_row_is_a_double_touch() -> void:
	var sim := _match()
	sim.ctx.rally.served = true
	assert_false(_touch(sim, 0), "première touche")
	assert_true(_touch(sim, 0), "deuxième touche du même joueur")
	assert_eq(sim.ctx.rally.fault_text, "double_touch", "motif")
	assert_eq(sim.ctx.rally.score[1], 1, "point pour l'équipe rouge")


func test_block_touch_is_not_counted_and_blocker_may_play_again() -> void:
	var sim := _match()
	sim.ctx.rally.served = true
	_touch(sim, 3)
	_touch(sim, 4)
	_touch(sim, 0, true, "block")
	assert_eq(sim.ctx.rally.touches[0], 0, "le contre ne compte pas")
	assert_false(_touch(sim, 0), "le contreur peut jouer ensuite sans double touche")
	assert_eq(sim.ctx.rally.touches[0], 1, "première touche de l'équipe bleue")


func test_ball_crossing_resets_touch_count_for_the_other_team() -> void:
	var sim := _match()
	sim.ctx.rally.served = true
	_touch(sim, 0)
	_touch(sim, 1)
	_touch(sim, 3)
	assert_eq(sim.ctx.rally.touches[0], 0, "compteur bleu remis à zéro")
	assert_eq(sim.ctx.rally.touches[1], 1, "compteur rouge = 1")


func test_landing_inside_scores_for_the_other_side_outside_penalizes_last_toucher() -> void:
	var sim := _match()
	sim.ctx.rally.served = true
	_touch(sim, 0)
	sim.referee.landing(3.0)   # côté droit (rouge) : point pour le bleu
	assert_eq(sim.ctx.rally.score, [1, 0] as Array[int], "atterrissage dans le camp rouge")
	var sim2 := _match()
	sim2.ctx.rally.served = true
	_touch(sim2, 0)
	sim2.referee.landing(sim2.court.half_length + 1.0)
	assert_eq(sim2.ctx.rally.score, [0, 1] as Array[int], "sorti après une touche bleue : point rouge")
	assert_eq(sim2.ctx.rally.fault_text, "out", "motif")


func test_ball_landing_before_being_served_is_a_service_fault() -> void:
	var sim := _match()
	sim.referee.landing(-2.0)
	assert_eq(sim.ctx.rally.fault_text, "service_fault", "service raté")
	assert_eq(sim.ctx.rally.score, [0, 1] as Array[int], "point pour l'adversaire du serveur")


func test_win_requires_target_points_and_two_point_lead() -> void:
	var sim := _match()
	var r := sim.ctx.rally
	r.score = [14, 14] as Array[int]
	sim.referee.award_point(0, "test")
	assert_eq(r.winner, -1, "15-14 : pas fini")
	sim.referee.award_point(1, "test")
	assert_eq(r.winner, -1, "15-15 : pas fini")
	sim.referee.award_point(1, "test")
	assert_eq(r.winner, -1, "15-16 : pas fini")
	sim.referee.award_point(1, "test")
	assert_eq(r.winner, 1, "15-17 : l'équipe rouge gagne")
	assert_eq(r.phase, Enums.Phase.POINT_AWARDED, "point attribué")
	var sim2 := _match()
	sim2.ctx.rally.score = [14, 3] as Array[int]
	sim2.referee.award_point(0, "test")
	assert_eq(sim2.ctx.rally.winner, 0, "15-3 : victoire nette")


func test_service_changes_on_side_out_and_server_rotates_attacker_setter_defender() -> void:
	var sim := _match()
	var r := sim.ctx.rally
	assert_eq(r.serving_team, 0, "le bleu sert d'abord")
	assert_eq(r.server_slot, 0, "attaquant bleu")
	sim.referee.award_point(0, "test")
	sim.referee.prepare_next_service()
	assert_eq(r.serving_team, 0, "l'équipe qui sert et marque garde le service")
	assert_eq(r.server_slot, 0, "même serveur")
	sim.referee.award_point(1, "test")
	sim.referee.prepare_next_service()
	assert_eq(r.serving_team, 1, "changement de service")
	assert_eq(sim.actors[r.server_slot].character.role, Enums.Role.ATTACKER, "premier serveur rouge : attaquant")
	sim.referee.award_point(0, "test")
	sim.referee.prepare_next_service()
	sim.referee.award_point(1, "test")
	sim.referee.prepare_next_service()
	assert_eq(r.serving_team, 1, "le rouge reprend le service")
	assert_eq(sim.actors[r.server_slot].character.role, Enums.Role.SETTER, "rotation : passeur")
