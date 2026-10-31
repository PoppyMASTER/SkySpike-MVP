extends TestCase
## Avec un joueur et des entrées scriptées par tick, le résultat ne dépend pas du FPS ni du ralenti.

const TARGET_TICKS := 1500


## Entrées scriptées : fonction pure du numéro de tick.
static func scripted_intent(tick: int) -> PlayerIntent:
	var axis := 1.0 if (tick / 90) % 2 == 0 else -1.0
	var jump := tick % 157 == 20 or tick % 157 == 45
	var receive := tick % 131 == 60
	return PlayerIntent.make(axis, jump, receive)


func _run(next_delta: Callable, time_scale := 1.0) -> Dictionary:
	var params := real_params()
	var clock := SimClock.new(params.get_value(ParamIds.SIM_HZ))
	clock.max_ticks_per_frame = 1000
	clock.max_frame_s = 1.0
	clock.time_scale = time_scale
	var sim := SimHelpers.make_sim("hammer_01", 11, clock.dt, params)
	var events := PackedStringArray()
	var frame := 0
	while sim.tick_count < TARGET_TICKS:
		var steps := clock.advance(next_delta.call(frame))
		frame += 1
		for i in steps:
			if sim.tick_count >= TARGET_TICKS:
				break
			var intents: Array[PlayerIntent] = [scripted_intent(sim.tick_count)]
			for e: MatchEvent in sim.tick(intents):
				events.append(e.to_text())
	return {"state": sim.state().fingerprint(), "events": "\n".join(events)}


func test_same_result_at_any_frame_rate_with_a_player() -> void:
	var at_60 := _run(func(_f: int) -> float: return 1.0 / 60.0)
	var at_30 := _run(func(_f: int) -> float: return 1.0 / 30.0)
	var at_144 := _run(func(_f: int) -> float: return 1.0 / 144.0)
	var rng := RandomNumberGenerator.new()   # hasard du TEST (durées d'image)
	rng.seed = 7
	var jitter := _run(func(_f: int) -> float: return rng.randf_range(0.002, 0.05))
	var slow := _run(func(_f: int) -> float: return 1.0 / 60.0, 0.25)
	assert_eq(at_30.state, at_60.state, "30 i/s = 60 i/s")
	assert_eq(at_144.state, at_60.state, "144 i/s = 60 i/s")
	assert_eq(jitter.state, at_60.state, "images irrégulières")
	assert_eq(slow.state, at_60.state, "ralenti ×0,25")
	assert_eq(jitter.events, at_60.events, "même journal d'événements")
	assert_true(at_60.events.count("PLAYER_JUMPED") >= 5, "le scénario fait bien sauter le joueur")
	assert_true(at_60.events.count("ACTION_STARTED") >= 3, "et engage des actions")


func test_player_run_is_reproducible_from_the_seed() -> void:
	var a := _run(func(_f: int) -> float: return 1.0 / 60.0)
	var b := _run(func(_f: int) -> float: return 1.0 / 60.0)
	assert_eq(a.state, b.state, "deux exécutions identiques")
