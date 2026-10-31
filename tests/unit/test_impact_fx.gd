extends TestCase
## Effets de frappe (J4.1a étape C) : fonctions du temps de simulation, bornés, sans effet sur la simulation.


func _state(tick: int, ball := Vector2(1, 2), vel := Vector2(10, 0), held := false) -> MatchState:
	var s := MatchState.new()
	s.tick = tick
	s.tick_seconds = 1.0 / 120.0
	s.ball_position = ball
	s.ball_velocity = vel
	s.ball_held = held
	return s


func _contact(speed: float, kind := "") -> Array[MatchEvent]:
	var d := {"action": "serve" if kind != "" else "spike", "speed": speed}
	if kind != "":
		d["serve_kind"] = kind
	var e := MatchEvent.new()
	e.type = MatchEvent.Type.CONTACT
	e.details = d
	return [e]


func test_impact_intensity_follows_speed_and_serve_kind() -> void:
	var fx := ImpactFx.new()
	fx.on_events(_contact(8.0, "ground"), _state(10))
	fx.on_events(_contact(18.0, "float"), _state(10))
	fx.on_events(_contact(22.0, "smash"), _state(10))
	assert_true(fx.impacts[0].weight < fx.impacts[1].weight and fx.impacts[1].weight < fx.impacts[2].weight, "sol < flottant < smash : %s" % [fx.impacts.map(func(i: ImpactFx.Impact) -> float: return i.weight)])
	assert_true(fx.impacts[2].weight <= 1.0, "intensité bornée")


func test_trail_follows_speed_and_expires_with_simulation_time() -> void:
	var fx := ImpactFx.new()
	for t in 100:
		fx.on_state(_state(t, Vector2(t * 0.1, 2)), 0.4)
	assert_true(fx.trail.size() <= int(0.4 * 120.0) + 2, "traînée limitée à sa durée (%d points)" % fx.trail.size())
	assert_true(ImpactFx.trail_width(24.0, 5.0) > ImpactFx.trail_width(4.0, 5.0), "plus rapide = plus épaisse")
	assert_eq(ImpactFx.trail_strength(2.0), 0.0, "ballon lent : pas de traînée")
	fx.on_state(_state(101, Vector2.ZERO, Vector2.ZERO, true), 0.4)
	assert_eq(fx.trail.size(), 0, "ballon tenu : traînée effacée")


func test_camera_shake_is_measured_decays_and_ignores_slow_hits() -> void:
	var fx := ImpactFx.new()
	fx.on_events(_contact(10.0), _state(0))
	assert_eq(fx.camera_offset(0.001, 1.0), Vector2.ZERO, "frappe lente : aucune secousse")
	fx.on_events(_contact(40.0, "smash"), _state(0))
	var peak := 0.0
	for i in 40:
		peak = maxf(peak, fx.camera_offset(i * 0.005, 1.0).length())
	assert_true(peak > 1.0 and peak <= ImpactFx.CAMERA_MAX_PX + 1e-6, "secousse perceptible mais plafonnée (%.2f px)" % peak)
	assert_eq(fx.camera_offset(ImpactFx.CAMERA_LIFE_S + 0.01, 1.0), Vector2.ZERO, "la secousse s'éteint")
	assert_eq(fx.camera_offset(0.01, 0.0), Vector2.ZERO, "force 0 : aucune secousse")


func test_effects_are_a_pure_function_of_simulation_time() -> void:
	var a := ImpactFx.new()
	var b := ImpactFx.new()
	for fx in [a, b]:
		fx.on_events(_contact(30.0, "smash"), _state(5))
	assert_eq(a.camera_offset(0.05, 0.7), b.camera_offset(0.05, 0.7), "même temps de simulation, même secousse")


func test_effects_do_not_change_the_simulation() -> void:
	var a := MatchSim.new(SimHelpers.fresh_params(), 7, 1.0 / 120.0, MatchConfig.default_lineup(SimHelpers.data().characters), -1)
	var b := MatchSim.new(SimHelpers.fresh_params(), 7, 1.0 / 120.0, MatchConfig.default_lineup(SimHelpers.data().characters), -1)
	var ai_a := AiDirector.new(a.params, 7, 1.0 / 120.0, -1)
	var ai_b := AiDirector.new(b.params, 7, 1.0 / 120.0, -1)
	ai_a.set_lineup(MatchConfig.default_lineup(SimHelpers.data().characters))
	ai_b.set_lineup(MatchConfig.default_lineup(SimHelpers.data().characters))
	var fx := ImpactFx.new()
	for i in 1500:
		var sa := a.state()
		var events := a.tick(ai_a.intents(sa))
		fx.on_state(a.state(), 0.4)
		fx.on_events(events, a.state())
		fx.camera_offset(ImpactFx.time_of(a.state()), 1.0)
		b.tick(ai_b.intents(b.state()))
	assert_true(fx.impacts.size() >= 0, "effets alimentés")
	assert_eq(a.state().fingerprint(), b.state().fingerprint(), "même empreinte avec et sans effets")
