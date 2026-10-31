extends TestCase
## SimClock : nombre de ticks indépendant du découpage du temps réel.


func _run(clock: SimClock, deltas: Array) -> int:
	var total := 0
	for d: float in deltas:
		total += clock.advance(d)
	return total


func test_one_second_gives_sim_hz_ticks_whatever_the_fps() -> void:
	for fps: int in [30, 60, 144]:
		var clock := SimClock.new(120)
		var deltas := []
		for i in fps:
			deltas.append(1.0 / fps)
		var n := _run(clock, deltas)
		assert_true(n >= 119 and n <= 120, "%d i/s → %d ticks (attendu 120, ±1 d'arrondi)" % [fps, n])


func test_time_scale_slows_without_changing_dt() -> void:
	var clock := SimClock.new(120)
	clock.time_scale = 0.5
	var deltas := []
	for i in 60:
		deltas.append(1.0 / 60.0)
	var n := _run(clock, deltas)
	assert_true(n >= 59 and n <= 60, "×0.5 → moitié des ticks (%d)" % n)
	assert_near(clock.dt, 1.0 / 120.0, 1e-12, "dt inchangé")


func test_pause_and_single_step() -> void:
	var clock := SimClock.new(120)
	clock.paused = true
	assert_eq(clock.advance(1.0), 0, "aucun tick en pause")
	clock.request_single_step()
	assert_eq(clock.advance(0.016), 1, "un seul tick demandé")
	assert_eq(clock.advance(0.016), 0, "puis plus rien")


func test_frame_cap_and_dropped_ticks() -> void:
	var clock := SimClock.new(120)
	clock.max_frame_s = 1.0
	clock.max_ticks_per_frame = 8
	assert_eq(clock.advance(0.5), 8, "plafonné à 8 ticks par image")
	var total := 8 + clock.dropped_ticks
	assert_true(total >= 59 and total <= 60, "le reste (0.5 s ≈ 60 ticks) est abandonné et compté : %d" % total)


func test_long_freeze_is_clamped() -> void:
	var clock := SimClock.new(120)
	clock.max_frame_s = 0.1
	clock.max_ticks_per_frame = 100
	var n := clock.advance(5.0)
	assert_true(n >= 11 and n <= 12, "un gel de 5 s ne compte que 0.1 s (%d ticks)" % n)
