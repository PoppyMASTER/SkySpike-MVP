extends TestCase
## Conversion stat (0–100) → grandeur physique : bornes, courbe, suivi des paramètres.


func _stats(value: int) -> StatsDefinition:
	var s := StatsDefinition.new()
	for f: String in StatsDefinition.FIELDS:
		s.set_stat(f, value)
	return s


func test_bounds_map_to_param_min_and_max() -> void:
	var p := real_params()
	assert_near(StatConversion.run_speed(_stats(0), p), p.get_value(ParamIds.SPEED_MIN), 1e-6, "stat 0 = min")
	assert_near(StatConversion.run_speed(_stats(100), p), p.get_value(ParamIds.SPEED_MAX), 1e-6, "stat 100 = max")
	assert_near(StatConversion.spike_angle_noise(_stats(100), p), p.get_value(ParamIds.SPIKE_NOISE_AT_100), 1e-6,
		"précision 100 = dispersion minimale")


func test_linear_midpoint() -> void:
	var p := real_params()
	var expected := (p.get_value(ParamIds.JUMP_APEX_MIN) + p.get_value(ParamIds.JUMP_APEX_MAX)) / 2.0
	assert_near(StatConversion.jump_apex(_stats(50), p), expected, 1e-6, "courbe 1 : milieu exact")


func test_curve_exponent_is_applied() -> void:
	assert_near(StatConversion.curve(50, 0.0, 1.0, 2.0), 0.25, 1e-9, "exposant 2 à mi-course")
	assert_near(StatConversion.curve(150, 0.0, 1.0, 1.0), 1.0, 1e-9, "stat au-delà de 100 bornée")


func test_conversion_follows_param_changes() -> void:
	var p := real_params()
	p.set_value(ParamIds.SPIKE_SPEED_MAX, 50.0)
	assert_near(StatConversion.spike_speed(_stats(100), p), 50.0, 1e-6, "le réglage est pris en compte immédiatement")


func test_every_conversion_is_monotonic() -> void:
	var p := real_params()
	var funcs: Array[Callable] = [StatConversion.run_speed, StatConversion.jump_apex, StatConversion.spike_speed,
		StatConversion.serve_speed, StatConversion.set_speed_max, StatConversion.block_factor]
	for f: Callable in funcs:
		assert_true(f.call(_stats(80), p) > f.call(_stats(20), p), "%s croît avec la stat" % f.get_method())
	var noises: Array[Callable] = [StatConversion.spike_angle_noise, StatConversion.set_angle_noise, StatConversion.receive_angle_noise]
	for f: Callable in noises:
		assert_true(f.call(_stats(80), p) < f.call(_stats(20), p), "%s décroît avec la précision" % f.get_method())
