extends TestCase
## Animation ↔ simulation : l'impact visuel tombe sur l'instant idéal, l'animation est une fonction de l'état de
## simulation (pas du FPS), les fondus sont continus, et le rendu n'influence jamais la simulation.

var _lib: ClipLibrary
var _character: CharacterDefinition


func _animator(character_id := "std_attacker_01") -> RigAnimator:
	if _lib == null:
		_lib = ClipLibrary.new()
		_lib.load_all("res://data")
	_character = SimHelpers.data().characters.get_character(character_id)
	return RigAnimator.new(_lib, _character)


func _snap(action: int, time := 0.0, ideal := 0.0, length := 0.0, grounded := true, velocity := Vector2.ZERO, x := 0.0, facing := 1) -> PlayerSnapshot:
	var s := PlayerSnapshot.new()
	s.action = action
	s.action_time = time
	s.action_ideal = ideal
	s.action_length = length
	s.grounded = grounded
	s.velocity = velocity
	s.position = Vector2(x, 0.0 if grounded else 1.0)
	s.facing = facing
	return s


func _eval(a: RigAnimator, s: PlayerSnapshot, tick := 100) -> AnimFrame:
	return a.evaluate(s, null, 1.0, tick, 1.0 / 120.0)


func test_visual_impact_lands_on_the_simulation_ideal_instant() -> void:
	for ideal in [0.06, 0.1, 0.2]:
		var a := _animator()
		var f := _eval(a, _snap(Enums.ActionState.SPIKE, ideal, ideal, 0.3, false))
		assert_near(f.clip_time, _lib.get_clip("spike_v1").marker("impact", 0.0), 1e-5, "smash : impact à l'instant idéal %.2f" % ideal)
	var b := _animator()
	assert_near(_eval(b, _snap(Enums.ActionState.RECEIVE, 0.14, 0.14, 0.3)).clip_time, _lib.get_clip("receive_v1").marker("impact", 0.0), 1e-5, "réception")
	assert_near(_eval(b, _snap(Enums.ActionState.SET, 0.12, 0.12, 0.28, true)).clip_time, _lib.get_clip("set_v1").marker("impact", 0.0), 1e-5, "passe")
	var c := _animator()
	var clip := _lib.get_clip("serve_v1")
	assert_near(_eval(c, _snap(Enums.ActionState.SERVE_HIT, 0.0, 0.12, 0.28)).clip_time, clip.marker("toss", 0.0), 1e-5, "service : départ au repère de lancer")
	assert_near(_eval(c, _snap(Enums.ActionState.SERVE_HIT, 0.12, 0.12, 0.28)).clip_time, clip.marker("impact", 0.0), 1e-5, "service : impact à l'instant idéal")


func test_hammer_character_uses_its_own_spike_clip_on_the_same_rig() -> void:
	var standard := _animator("std_attacker_01")
	var hammer := _animator("hammer_01")
	var s := _snap(Enums.ActionState.SPIKE, 0.1, 0.1, 0.22, false)
	assert_eq(_eval(standard, s).clip_id, "spike_v1", "smash standard")
	assert_eq(_eval(hammer, s).clip_id, "hammer_spike_v1", "smash marteau")
	var pose: Dictionary = _eval(hammer, s).pose
	assert_true(absf(float(pose["upper_arm_l"]) - float(pose["upper_arm_r"])) < 0.3, "deux bras presque symétriques (deux mains)")
	var one_hand: Dictionary = _eval(standard, s).pose
	assert_true(absf(float(one_hand["upper_arm_l"]) - float(one_hand["upper_arm_r"])) > 1.5, "une main : les bras diffèrent")
	assert_eq(hammer.dims.standing_height() > standard.dims.standing_height(), true, "morphologie du marteau visible (taille 1,05)")


func test_every_simulation_state_maps_to_a_clip() -> void:
	var a := _animator()
	var expected := {
		Enums.ActionState.LOCKED: "idle_v1", Enums.ActionState.FREE: "idle_v1", Enums.ActionState.RECEIVE: "receive_v1",
		Enums.ActionState.SET: "set_v1", Enums.ActionState.BLOCK_READY: "block_v1", Enums.ActionState.AIR: "jump_v1",
		Enums.ActionState.SPIKE: "spike_v1", Enums.ActionState.FEINT: "feint_v1", Enums.ActionState.BLOCK_AIR: "block_v1",
		Enums.ActionState.RECOVER: "land_v1", Enums.ActionState.SERVE_HOLD: "serve_v1", Enums.ActionState.SERVE_TOSS: "serve_v1",
		Enums.ActionState.SERVE_JUMP: "serve_v1", Enums.ActionState.SERVE_HIT: "serve_v1",
	}
	for state: int in expected:
		var grounded: bool = not [Enums.ActionState.AIR, Enums.ActionState.SPIKE, Enums.ActionState.FEINT, Enums.ActionState.BLOCK_AIR, Enums.ActionState.SERVE_JUMP].has(state)
		assert_eq(_eval(_animator(), _snap(state, 0.05, 0.1, 0.2, grounded)).clip_id, expected[state], "état %s" % Enums.action_to_string(state))
	assert_eq(a.evaluate(_snap(Enums.ActionState.FREE, 0, 0, 0, true, Vector2(5, 0)), null, 1.0, 10, 0.01).clip_id, "run_v1", "course")
	assert_eq(a.evaluate(_snap(Enums.ActionState.FREE, 0, 0, 0, false, Vector2(0, 3)), null, 1.0, 10, 0.01).clip_id, "jump_v1", "en l'air hors action")


func test_run_cycle_depends_on_distance_and_direction_not_on_time() -> void:
	var a := _animator()
	var clip := _lib.get_clip("run_v1")
	var run := func(x: float, facing: int, tick: int) -> AnimFrame:
		return _animator().evaluate(_snap(Enums.ActionState.FREE, 0, 0, 0, true, Vector2(5 * facing, 0), x, facing), null, 1.0, tick, 1.0 / 120.0)
	assert_near(run.call(0.8, 1, 10).clip_time, run.call(0.8, 1, 999).clip_time, 1e-6, "même position → même phase, quel que soit le temps")
	assert_near(run.call(0.8, 1, 10).clip_time, run.call(0.8 + clip.stride_m, 1, 10).clip_time, 1e-4, "une foulée plus loin → même phase")
	assert_near(run.call(0.8, -1, 10).clip_time, run.call(-0.8, 1, 10).clip_time, 1e-4, "tourné vers la gauche : phase symétrique")
	var ahead: float = run.call(1.0, 1, 10).clip_time
	var behind: float = run.call(0.5, 1, 10).clip_time
	assert_true(ahead > behind, "avancer fait progresser le cycle, reculer le fait rejouer à l'envers")


func test_jump_pose_follows_vertical_velocity() -> void:
	var clip := _lib if _lib != null else null
	var a := _animator()
	var ref := _lib.get_clip("jump_v1").air_ref_speed
	var up := a.evaluate(_snap(Enums.ActionState.AIR, 0.0, 0, 0, false, Vector2(0, ref)), null, 1.0, 5, 0.01)
	var apex := _animator().evaluate(_snap(Enums.ActionState.AIR, 0.3, 0, 0, false, Vector2(0, 0)), null, 1.0, 5, 0.01)
	var down := _animator().evaluate(_snap(Enums.ActionState.AIR, 0.7, 0, 0, false, Vector2(0, -ref)), null, 1.0, 5, 0.01)
	assert_near(up.progress(), 0.0, 1e-5, "décollage : début du clip")
	assert_near(apex.progress(), 0.5, 1e-5, "sommet : milieu")
	assert_near(down.progress(), 1.0, 1e-5, "chute : fin")
	assert_eq(up.shift_y, 0.0, "en l'air : pas de calage sur le sol")


func test_landing_clip_is_stretched_over_the_simulated_recovery_time() -> void:
	var half := _eval(_animator(), _snap(Enums.ActionState.RECOVER, 0.04, 0.0, 0.08))
	assert_near(half.progress(), 0.5, 1e-5, "mi-récupération = milieu du clip")
	assert_near(_eval(_animator(), _snap(Enums.ActionState.RECOVER, 0.5, 0.0, 0.08)).progress(), 1.0, 1e-5, "au-delà : dernière pose")


func test_holds_use_clip_markers() -> void:
	var clip := _lib.get_clip("serve_v1") if _lib != null else null
	var a := _animator()
	var hold := _eval(a, _snap(Enums.ActionState.SERVE_HOLD))
	assert_near(hold.clip_time, _lib.get_clip("serve_v1").marker("hold", -1.0), 1e-6, "service tenu : repère « hold »")
	var toss := _eval(_animator(), _snap(Enums.ActionState.SERVE_TOSS, 0.2))
	assert_near(toss.clip_time, _lib.get_clip("serve_v1").marker("toss", -1.0), 1e-6, "ballon lancé : repère « toss »")
	var ready := _eval(_animator(), _snap(Enums.ActionState.BLOCK_READY, 0.3))
	assert_near(ready.clip_time, 0.0, 1e-6, "contre prêt : pose d'attente figée")


func test_blend_starts_from_the_previous_pose_and_ends_on_the_target() -> void:
	var a := _animator()
	var idle_pose: Dictionary = a.evaluate(_snap(Enums.ActionState.FREE), null, 1.0, 100, 0.01).pose.duplicate()
	var start := a.evaluate(_snap(Enums.ActionState.RECEIVE, 0.0, 0.14, 0.3), null, 1.0, 101, 0.01)
	assert_near(start.blend, 0.0, 1e-6, "début du fondu")
	assert_near(float(start.pose["thigh_l"]), float(idle_pose["thigh_l"]), 1e-5, "aucun saut de posture au premier instant")
	var mid := a.evaluate(_snap(Enums.ActionState.RECEIVE, 0.02, 0.14, 0.3), null, 1.0, 103, 0.01)
	assert_true(mid.blend > 0.0 and mid.blend < 1.0, "fondu en cours")
	var done := a.evaluate(_snap(Enums.ActionState.RECEIVE, 0.2, 0.14, 0.3), null, 1.0, 120, 0.01)
	assert_eq(done.blend, 1.0, "fondu terminé")
	var target := _lib.get_clip("receive_v1").sample(done.clip_time)
	assert_near(float(done.pose["thigh_l"]), float(target["thigh_l"]), 1e-5, "pose finale = pose du clip")


func test_pause_freezes_the_pose_and_restart_resets_the_blend() -> void:
	var a := _animator()
	var s := _snap(Enums.ActionState.RECEIVE, 0.03, 0.14, 0.3)
	a.evaluate(_snap(Enums.ActionState.FREE), null, 1.0, 100, 0.01)
	var p1 := a.evaluate(s, null, 1.0, 101, 0.01)
	var p2 := a.evaluate(s, null, 1.0, 101, 0.01)
	assert_near(float(p1.pose["torso"]), float(p2.pose["torso"]), 1e-9, "même instant de simulation → même pose (pause)")
	var restarted := a.evaluate(s, null, 1.0, 1, 0.01)
	assert_eq(restarted.blend, 1.0, "après un redémarrage : pas de fondu depuis l'ancien match")


func test_animation_speed_scales_playback_but_not_the_simulation_anchor() -> void:
	var s := _snap(Enums.ActionState.SPIKE, 0.2, 0.1, 0.3, false)
	var normal := _animator().evaluate(s, null, 1.0, 100, 0.01, 1.0)
	var fast := _animator().evaluate(s, null, 1.0, 100, 0.01, 2.0)
	assert_true(fast.clip_time > normal.clip_time, "×2 : lecture plus rapide après l'impact")
	var at_ideal := _snap(Enums.ActionState.SPIKE, 0.1, 0.1, 0.3, false)
	assert_near(_animator().evaluate(at_ideal, null, 1.0, 100, 0.01, 2.0).clip_time, _animator().evaluate(at_ideal, null, 1.0, 100, 0.01, 0.5).clip_time, 1e-6, "l'impact reste sur l'instant idéal quelle que soit la vitesse")


func test_rendering_never_changes_the_simulation() -> void:
	var data := SimHelpers.data()
	var lineup := MatchConfig.default_lineup(data.characters)
	var dt := 1.0 / data.params.get_value(ParamIds.SIM_HZ)
	var plain := MatchSim.new(SimHelpers.fresh_params(), 4, dt, lineup, -1)
	var drawn := MatchSim.new(SimHelpers.fresh_params(), 4, dt, lineup, -1)
	var ai_a := AiDirector.new(plain.params, 4, dt, -1)
	var ai_b := AiDirector.new(drawn.params, 4, dt, -1)
	ai_a.set_lineup(lineup)
	ai_b.set_lineup(lineup)
	var animators: Array[RigAnimator] = []
	_animator()
	for c in lineup:
		animators.append(RigAnimator.new(_lib, c))
	var before: MatchState = null
	for t in 1500:
		plain.tick(ai_a.intents(plain.state()))
		drawn.tick(ai_b.intents(drawn.state()))
		var state := drawn.state()
		for i in animators.size():
			animators[i].evaluate(state.players[i], before.players[i] if before != null else null, (t % 7) / 7.0, state.tick, state.tick_seconds, 0.3 + (t % 5))
		before = state
	assert_eq(drawn.state().fingerprint(), plain.state().fingerprint(), "avec ou sans rendu : même état de simulation")
