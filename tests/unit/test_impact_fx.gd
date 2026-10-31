extends TestCase
## Effets de frappe (J4.1a étape C, J4.1 SJ2) : fonctions du temps de simulation, bornés, style selon le type RÉEL,
## intensité selon vitesse et qualité réelles, sans effet sur la simulation.


func _params() -> ParamStore:
	return SimHelpers.fresh_params()


func _state(tick: int, ball := Vector2(1, 2), vel := Vector2(10, 0), held := false) -> MatchState:
	var s := MatchState.new()
	s.tick = tick
	s.tick_seconds = 1.0 / 120.0
	s.ball_position = ball
	s.ball_velocity = vel
	s.ball_held = held
	return s


func _contact(speed: float, kind := "", q := 1.0, intent := "") -> Array[MatchEvent]:
	var d := {"action": "serve" if kind != "" else "spike", "speed": speed, "q": q}
	if kind != "":
		d["serve_kind"] = kind
	if intent != "":
		d["serve_intent"] = intent
	var e := MatchEvent.new()
	e.type = MatchEvent.Type.CONTACT
	e.details = d
	return [e]


func test_intensity_follows_real_speed_and_quality() -> void:
	var p := _params()
	assert_true(HitIntensity.compute(10.0, 1.0, "smash", p) < HitIntensity.compute(20.0, 1.0, "smash", p), "plus rapide = plus intense")
	assert_true(HitIntensity.compute(20.0, 0.3, "smash", p) < HitIntensity.compute(20.0, 0.9, "smash", p), "plus propre = plus intense")
	for kind in ["", "ground", "float", "smash"]:
		for speed in [0.0, 5.0, 15.0, 40.0, 90.0]:
			for q in [0.0, 0.5, 1.0]:
				var i := HitIntensity.compute(speed, q, kind, p)
				assert_true(i >= 0.0 and i <= 1.0, "intensité bornée (%s, %.0f, %.1f)" % [kind, speed, q])
	var floor_ratio: float = p.get_value(ParamIds.FX_QUALITY_FLOOR)
	assert_near(HitIntensity.compute(99.0, 0.0, "smash", p), floor_ratio, 1e-6, "qualité nulle : il reste le plancher")
	# Chaque service a sa propre échelle : un flottant à 17 m/s est « plein » sans être comparé au smash.
	assert_near(HitIntensity.compute(p.get_value(ParamIds.FX_SPEED_FULL_FLOAT), 1.0, "float", p), 1.0, 1e-6, "flottant plein")


func test_spectacular_effects_need_a_fast_and_clean_smash() -> void:
	var p := _params()
	var full: float = p.get_value(ParamIds.FX_SPEED_FULL_SMASH)
	assert_true(HitIntensity.is_exceptional(full, 0.95, "smash", p), "smash rapide et propre : exceptionnel")
	assert_false(HitIntensity.is_exceptional(full, 0.2, "smash", p), "smash rapide mais raté : pas d'effet exceptionnel")
	assert_true(HitIntensity.compute(full, 0.2, "smash", p) >= 0.25, "… mais il garde une sensation de puissance")
	assert_false(HitIntensity.is_exceptional(full * 0.4, 1.0, "smash", p), "smash propre mais lent : pas exceptionnel")
	assert_false(HitIntensity.is_exceptional(full, 1.0, "float", p), "flottant : jamais exceptionnel")
	assert_false(HitIntensity.is_exceptional(40.0, 1.0, "", p), "attaque : pas de caméra de service")


func test_style_follows_the_real_kind_and_a_miss_has_no_effect() -> void:
	var fx := ImpactFx.new(_params())
	fx.on_events(_contact(20.0, "float", 1.0, "smash"), _state(10))
	assert_eq(fx.impacts[0].kind, "float", "style du type RÉEL au contact, pas de l'intention")
	var miss := MatchEvent.new()
	miss.type = MatchEvent.Type.ACTION_MISSED
	miss.details = {"action": "serve"}
	var events: Array[MatchEvent] = [miss]
	fx.on_events(events, _state(11))
	assert_eq(fx.impacts.size(), 1, "frappe manquée : aucun impact")
	fx.on_events(_contact(25.0, "smash", 0.2), _state(12))
	assert_false(fx.impacts[1].exceptional, "smash raté : pas exceptionnel")
	assert_true(FxOverlay.impact_color(fx.impacts[1]).s < FxOverlay.impact_color(_smash(1.0)).s, "smash raté : couleur ternie")


func _smash(q: float) -> ImpactFx.Impact:
	var fx := ImpactFx.new(_params())
	fx.on_events(_contact(25.0, "smash", q), _state(0))
	return fx.impacts[0]


func test_trail_keeps_the_style_and_life_of_its_hit_and_expires_with_simulation_time() -> void:
	var p := _params()
	var fx := ImpactFx.new(p)
	fx.on_events(_contact(20.0, "smash"), _state(0))
	for t in 200:
		fx.on_state(_state(t, Vector2(t * 0.1, 2), Vector2(20, 0)))
	var life: float = p.get_value(ParamIds.FX_TRAIL_SMASH_S)
	assert_true(fx.trail.size() <= int(life * 120.0) + 2, "traînée limitée à sa durée (%d points)" % fx.trail.size())
	assert_eq(String(fx.trail[0].k), "smash", "les points gardent le style de leur frappe")
	assert_true(ImpactFx.trail_width(24.0, 5.0) > ImpactFx.trail_width(4.0, 5.0), "plus rapide = plus épaisse")
	assert_eq(ImpactFx.trail_strength(2.0), 0.0, "ballon lent : pas de traînée")
	fx.on_state(_state(201, Vector2.ZERO, Vector2.ZERO, true))
	assert_eq(fx.trail.size(), 0, "ballon tenu : traînée effacée")


func test_camera_shake_only_for_a_clean_fast_smash_measured_and_short() -> void:
	var p := _params()
	var fx := ImpactFx.new(p)
	fx.on_events(_contact(40.0), _state(0))
	fx.on_events(_contact(40.0, "float"), _state(0))
	fx.on_events(_contact(40.0, "smash", 0.2), _state(0))
	for i in 30:
		assert_eq(fx.camera_offset(i * 0.005, 1.0), Vector2.ZERO, "attaque, flottant ou smash raté : aucune secousse")
	fx.on_events(_contact(30.0, "smash", 1.0), _state(0))
	var peak := 0.0
	for i in 60:
		peak = maxf(peak, fx.camera_offset(i * 0.0025, 1.0).length())
	assert_true(peak > 0.5 and peak <= ImpactFx.CAMERA_MAX_PX + 1e-6, "secousse perceptible mais plafonnée (%.2f px)" % peak)
	assert_true(ImpactFx.CAMERA_LIFE_S <= 0.2, "secousse très courte")
	assert_eq(fx.camera_offset(ImpactFx.CAMERA_LIFE_S + 0.01, 1.0), Vector2.ZERO, "elle s'éteint et revient au centre")
	assert_eq(fx.camera_offset(0.01, 0.0), Vector2.ZERO, "force 0 : aucune secousse")
	# Le ballon reste lisible : décalage de quelques pixels sur un écran de 1600 px, jamais de quoi le perdre.
	assert_true(ImpactFx.CAMERA_MAX_PX < 0.01 * 1600.0, "amplitude négligeable devant l'écran")


func test_effects_are_a_pure_function_of_simulation_time() -> void:
	var a := ImpactFx.new(_params())
	var b := ImpactFx.new(_params())
	for fx in [a, b]:
		fx.on_events(_contact(30.0, "smash"), _state(5))
	assert_eq(a.camera_offset(0.05, 0.7), b.camera_offset(0.05, 0.7), "même temps de simulation, même secousse")
	var point := {"p": Vector2.ZERO, "t": 0.3, "v": 15.0, "k": "float", "i": 1.0, "life": 0.35, "c": 0.1}
	assert_eq(FxOverlay.wobble(point, 0.5, 0.05, 5.0), FxOverlay.wobble(point, 0.5, 0.05, 5.0), "ondulation reproductible")


func test_ball_stays_visible_during_impacts() -> void:
	# Les effets sont dessinés SOUS le ballon ; en plus, les anneaux s'ouvrent toujours à distance du ballon et
	# l'éclair reste translucide : même un impact de smash maximal ne recouvre jamais le ballon.
	var p := _params()
	var k := 1600.0 / MatchView.VISIBLE_WIDTH_M
	var ball_px := 0.105 * k
	for impact in [_smash(1.0), _smash(0.1)]:
		for i in 21:
			var r := FxOverlay.ring_radius(impact, i / 20.0, k, p.get_value(ParamIds.FX_IMPACT_SCALE), ball_px)
			assert_true(r >= ball_px * 1.5, "anneau à distance du ballon (%.1f px pour un ballon de %.1f px)" % [r, ball_px])
	assert_true(FxOverlay.FLASH_MAX_ALPHA <= 0.4, "éclair translucide")
	assert_true(ImpactFx.FLASH_LIFE_S <= 0.1, "éclair très bref")
	# Ondulation du flottant : nulle au niveau du ballon, la traînée rejoint la vraie position.
	var fresh := {"p": Vector2.ZERO, "t": 1.0, "v": 15.0, "k": "float", "i": 1.0, "life": 0.35, "c": 0.9}
	assert_eq(FxOverlay.wobble(fresh, 1.0, 0.2, 5.0), 0.0, "ondulation nulle au ballon")
	for t in 40:
		assert_true(absf(FxOverlay.wobble(fresh, 1.0 + t * 0.01, 0.05, 5.0)) <= 0.05 + 1e-6, "ondulation bornée par le réglage")


func test_prediction_and_trail_cannot_be_confused() -> void:
	# Prévision = pointillés verts / rouges ; traînée = ruban continu blanc, bleu clair, cyan ou jaune-orangé.
	var prediction := [MatchOverlay.COLOR_PREVIEW_OK, MatchOverlay.COLOR_PREVIEW_BAD]
	for kind in ["ground", "float", "smash"]:
		for i in [0.0, 0.5, 1.0]:
			var c: Color = FxOverlay.trail_style({"v": 20.0, "i": i, "k": kind}).color
			for pc: Color in prediction:
				var dh := absf(c.h - pc.h)
				dh = minf(dh, 1.0 - dh)
				assert_true(dh > 0.05 or c.s < 0.25, "traînée %s (%s) distincte de la prévision (%s)" % [kind, c.to_html(false), pc.to_html(false)])


func test_landing_marker_tightens_as_the_ball_comes_down() -> void:
	var k := 72.0
	assert_true(MatchOverlay.landing_marker_radius(1.5, k) > MatchOverlay.landing_marker_radius(0.2, k), "repère resserré juste avant la retombée")
	assert_true(MatchOverlay.landing_marker_radius(0.0, k) >= 0.1 * k, "repère toujours identifiable")


func test_speed_labels_per_kind() -> void:
	var fx := ImpactFx.new(_params())
	fx.on_events(_contact(15.0, "ground"), _state(0))
	fx.on_events(_contact(15.0, "float"), _state(0))
	fx.on_events(_contact(25.0, "smash"), _state(0))
	assert_false(FxOverlay.label_shown(fx.impacts[0], false), "sol : km/h désactivés par défaut")
	assert_true(FxOverlay.label_shown(fx.impacts[0], true), "sol : activables")
	assert_true(FxOverlay.label_shown(fx.impacts[1], false) and FxOverlay.label_shown(fx.impacts[2], false), "flottant et smash : km/h")


func test_settings_off_or_at_zero_remove_the_effects() -> void:
	var p := _params()
	var view := MatchView.new()
	view.params = p
	view.current_state = _state(10)
	view.on_events(_contact(25.0, "smash"), view.current_state)
	assert_eq(view.fx.impacts.size(), 1, "effets activés : un impact")
	p.set_value(ParamIds.FX_ENABLED, 0.0)
	view.on_events(_contact(25.0, "smash"), view.current_state)
	view._update_fx()
	assert_eq(view.fx.impacts.size(), 0, "effets désactivés : plus aucun impact")
	assert_eq(view.camera_px, Vector2.ZERO, "effets désactivés : caméra au centre")
	p.set_value(ParamIds.FX_ENABLED, 1.0)
	p.set_value(ParamIds.FX_TRAIL_S, 0.0)
	var fx := ImpactFx.new(p)
	for t in 30:
		fx.on_state(_state(t, Vector2(t * 0.1, 2), Vector2(20, 0)))
	assert_true(fx.trail.size() <= 1, "traînée réglée à 0 : rien ne reste")
	p.set_value(ParamIds.FX_FLOAT_WOBBLE_M, 0.0)
	var point := {"p": Vector2.ZERO, "t": 0.3, "v": 15.0, "k": "float", "i": 1.0, "life": 0.35, "c": 0.1}
	assert_eq(FxOverlay.wobble(point, 0.5, p.get_value(ParamIds.FX_FLOAT_WOBBLE_M), 5.0), 0.0, "ondulation à 0 : traînée droite")
	view.free()


func test_effects_do_not_change_the_simulation() -> void:
	var a := MatchSim.new(SimHelpers.fresh_params(), 7, 1.0 / 120.0, MatchConfig.default_lineup(SimHelpers.data().characters), -1)
	var b := MatchSim.new(SimHelpers.fresh_params(), 7, 1.0 / 120.0, MatchConfig.default_lineup(SimHelpers.data().characters), -1)
	var ai_a := AiDirector.new(a.params, 7, 1.0 / 120.0, -1)
	var ai_b := AiDirector.new(b.params, 7, 1.0 / 120.0, -1)
	ai_a.set_lineup(MatchConfig.default_lineup(SimHelpers.data().characters))
	ai_b.set_lineup(MatchConfig.default_lineup(SimHelpers.data().characters))
	var fx := ImpactFx.new(a.params)
	for i in 1500:
		var sa := a.state()
		var events := a.tick(ai_a.intents(sa))
		fx.on_state(a.state())
		fx.on_events(events, a.state())
		fx.camera_offset(ImpactFx.time_of(a.state()), 1.0)
		b.tick(ai_b.intents(b.state()))
	assert_true(fx.impacts.size() >= 0, "effets alimentés")
	assert_eq(a.state().fingerprint(), b.state().fingerprint(), "même empreinte avec et sans effets")
