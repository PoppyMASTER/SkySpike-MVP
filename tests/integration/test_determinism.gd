extends TestCase
## Même graine + mêmes paramètres → même résultat logique, quel que soit le découpage
## du temps réel (FPS de rendu) et le ralenti. Critère d'acceptation 11 du CDC (J1 : ballon seul).

const TARGET_TICKS := 2400   # 20 s de jeu à 120 ticks/s


## Fait tourner une simulation jusqu'à TARGET_TICKS en découpant le temps réel selon `next_delta`.
func _run(seed_value: int, next_delta: Callable, time_scale := 1.0) -> Dictionary:
	var params := real_params()
	var clock := SimClock.new(params.get_value(ParamIds.SIM_HZ))
	clock.max_ticks_per_frame = 1000
	clock.max_frame_s = 1.0
	clock.time_scale = time_scale
	var sim := MatchSim.new(params, seed_value, clock.dt)
	var events := PackedStringArray()
	var frame := 0
	while sim.tick_count < TARGET_TICKS:
		var steps := clock.advance(next_delta.call(frame))
		frame += 1
		for i in steps:
			if sim.tick_count >= TARGET_TICKS:
				break
			for e: MatchEvent in sim.tick():
				events.append(e.to_text())
	return {"state": sim.state().fingerprint(), "events": "\n".join(events), "frames": frame}


func test_same_result_at_30_60_144_fps_and_with_jitter() -> void:
	var at_60 := _run(42, func(_f: int) -> float: return 1.0 / 60.0)
	var at_30 := _run(42, func(_f: int) -> float: return 1.0 / 30.0)
	var at_144 := _run(42, func(_f: int) -> float: return 1.0 / 144.0)
	var jitter_rng := RandomNumberGenerator.new()   # hasard du TEST (durées d'image), pas de la simulation
	jitter_rng.seed = 99
	var jitter := _run(42, func(_f: int) -> float: return jitter_rng.randf_range(0.002, 0.05))
	assert_eq(at_30.state, at_60.state, "état final identique à 30 et 60 i/s")
	assert_eq(at_144.state, at_60.state, "état final identique à 144 et 60 i/s")
	assert_eq(jitter.state, at_60.state, "état final identique avec des images irrégulières")
	assert_eq(at_30.events, at_60.events, "journal d'événements identique")
	assert_eq(jitter.events.hash(), at_60.events.hash(), "empreinte du journal identique")
	assert_true(at_60.events.count("BALL_LANDED") >= 5, "l'exercice produit bien plusieurs atterrissages")


func test_slow_motion_does_not_change_the_result() -> void:
	var normal := _run(7, func(_f: int) -> float: return 1.0 / 60.0)
	var slow := _run(7, func(_f: int) -> float: return 1.0 / 60.0, 0.25)
	assert_eq(slow.state, normal.state, "ralenti ×0.25 : même état au même tick")
	assert_true(slow.frames > normal.frames * 3, "mais il faut ~4 fois plus d'images")


func test_different_seeds_give_different_results() -> void:
	var a := _run(1, func(_f: int) -> float: return 1.0 / 60.0)
	var b := _run(2, func(_f: int) -> float: return 1.0 / 60.0)
	assert_true(a.state != b.state, "graines différentes → trajectoires différentes")
