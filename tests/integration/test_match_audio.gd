extends TestCase
## Sons de frappe (J4.1 SJ2) : synthèse déterministe sans saturation, un son par contact de service réel, voix
## plafonnées, contacts rapprochés fusionnés, pause, ralenti, réglages à zéro, aucun effet sur la simulation.

const DIR := "user://test_audio"


func _audio(params: ParamStore = null) -> MatchAudio:
	var p := params if params != null else SimHelpers.fresh_params()
	var audio := MatchAudio.new(p, AudioBank.load_default())
	(Engine.get_main_loop() as SceneTree).root.add_child(audio)
	return audio


func _done(audio: MatchAudio) -> void:
	audio.get_parent().remove_child(audio)
	audio.free()


func _state(tick: int) -> MatchState:
	var s := MatchState.new()
	s.tick = tick
	s.tick_seconds = 1.0 / 120.0
	return s


func _contact(speed: float, kind := "", q := 1.0) -> Array[MatchEvent]:
	var e := MatchEvent.new()
	e.type = MatchEvent.Type.CONTACT
	e.details = {"action": "serve" if kind != "" else "spike", "speed": speed, "q": q}
	if kind != "":
		e.details["serve_kind"] = kind
	return [e]


func test_synthesis_is_deterministic_bounded_and_never_clips() -> void:
	var bank := AudioBank.load_default()
	assert_eq(bank.issues.size(), 0, "sons chargés sans problème")
	for id in ["serve_ground", "serve_float", "serve_smash"]:
		assert_true(bank.has_cue(id), "son « %s »" % id)
		var cue: SoundCueDefinition = bank.cues[id]
		for tier in ProceduralSound.TIERS:
			var a := ProceduralSound.samples(cue, tier)
			var b := ProceduralSound.samples(cue, tier)
			assert_eq(a, b, "%s : même recette, mêmes échantillons" % id)
			var peak := ProceduralSound.peak_of(a)
			assert_true(peak <= ProceduralSound.PEAK_LIMIT + 1e-4, "%s : pic %.3f sous −1 dBFS" % [id, peak])
			assert_true(peak > 0.05, "%s : son audible" % id)
			assert_true(a.size() <= int(0.5 * ProceduralSound.MIX_RATE), "%s : son court" % id)
			assert_true(absf(a[a.size() - 1]) < 0.01, "%s : fin sans clic" % id)
	# Identités sonores : le smash est le plus long et le plus grave, le flottant le plus bref.
	var g: SoundCueDefinition = bank.cues["serve_ground"]
	var f: SoundCueDefinition = bank.cues["serve_float"]
	var s: SoundCueDefinition = bank.cues["serve_smash"]
	assert_true(s.duration_s > g.duration_s and g.duration_s > f.duration_s, "durées : smash > sol > flottant")
	assert_true(s.tone_end_hz < g.tone_end_hz and g.tone_end_hz < f.tone_end_hz, "le smash est le plus grave")


func test_missing_or_invalid_files_fall_back_to_synthesis() -> void:
	var issues: Array[LoadIssue] = []
	write_json(DIR.path_join("cues.json"), {"schema_version": 1, "cues": [
		{"id": "serve_smash", "file": "res://absent.ogg", "volume_db": 99.0, "synth": {"duration_s": 0.2, "bogus": 1}}]})
	var cues := SoundCueLoader.load_cues(DIR.path_join("cues.json"), issues)
	assert_true(issues.size() >= 2, "volume hors bornes et champ inconnu signalés (%d)" % issues.size())
	var bank := AudioBank.new()
	bank.build(cues)
	assert_true(bank.has_cue("serve_smash") and not bank.uses_file("serve_smash"), "fichier absent : son synthétisé")
	assert_true(bank.issues.size() == 1, "fichier absent signalé")
	remove_dir(DIR)


func test_one_sound_per_real_serve_contact_and_none_for_a_miss() -> void:
	var audio := _audio()
	audio.on_events(_contact(15.0, "ground"), _state(10))
	audio.on_events(_contact(20.0), _state(100))   # attaque : pas de son de service
	var miss := MatchEvent.new()
	miss.type = MatchEvent.Type.ACTION_MISSED
	miss.details = {"action": "serve"}
	var events: Array[MatchEvent] = [miss]
	audio.on_events(events, _state(200))
	audio.on_events(_contact(16.0, "float"), _state(300))
	audio.on_events(_contact(25.0, "smash"), _state(400))
	assert_eq(audio.played.map(func(x: Dictionary) -> String: return x.cue), ["serve_ground", "serve_float", "serve_smash"], "un son par service réel")
	_done(audio)


func test_volume_follows_real_intensity() -> void:
	var audio := _audio()
	audio.on_events(_contact(25.0, "smash", 1.0), _state(10))
	audio.on_events(_contact(25.0, "smash", 0.2), _state(200))
	audio.on_events(_contact(10.0, "smash", 1.0), _state(400))
	var v: Array = audio.played.map(func(x: Dictionary) -> float: return x.volume_db)
	assert_true(v[0] > v[1] and v[0] > v[2], "smash propre et rapide le plus fort (%s)" % [v])
	for x in v:
		assert_true(float(x) <= 0.0, "jamais au-dessus de 0 dB (%.1f)" % x)
	_done(audio)


func test_close_contacts_are_merged_and_voices_are_capped() -> void:
	var p := SimHelpers.fresh_params()
	var audio := _audio(p)
	for i in 6:   # six contacts de moins en moins forts en 6 ticks (0,05 s) : un seul son
		audio.on_events(_contact(28.0 - i * 3.0, "smash"), _state(10 + i))
	assert_eq(audio.played.size(), 1, "contacts rapprochés plus faibles : fusionnés dans le premier")
	for i in 6:   # de plus en plus forts : chacun remplace le précédent sur la MÊME voix
		audio.on_events(_contact(4.0 + i * 1.5, "smash"), _state(100 + i))
	assert_eq(audio.playing_count(), 1, "contacts rapprochés : une seule voix occupée")
	assert_eq(int(audio.played[audio.played.size() - 1].tick), 105, "le plus fort l'emporte")
	for i in 40:   # contacts espacés : plafond de voix
		audio.on_events(_contact(25.0, "smash"), _state(300 + i * 20))
	assert_true(audio.voice_count() <= int(p.get_value(ParamIds.AUDIO_MAX_VOICES)), "voix plafonnées (%d)" % audio.voice_count())
	var bus := MatchAudio.ensure_bus()   # appelé par _ready dans le jeu
	assert_true(bus >= 0 and AudioServer.get_bus_effect(bus, 0) is AudioEffectHardLimiter, "bus « Effets » protégé par un limiteur")
	assert_true((AudioServer.get_bus_effect(bus, 0) as AudioEffectHardLimiter).ceiling_db <= -1.0, "plafond du limiteur −1 dB")
	_done(audio)


func test_pause_slow_motion_and_settings_at_zero() -> void:
	var p := SimHelpers.fresh_params()
	var audio := _audio(p)
	audio.set_paused(true)
	audio.on_events(_contact(25.0, "smash"), _state(10))
	assert_true(audio.is_paused() and audio.played.size() == 1, "en pause : le son est préparé mais suspendu")
	audio.set_paused(false)
	p.set_value(ParamIds.TIME_SCALE, 0.25)
	audio.on_events(_contact(25.0, "smash"), _state(300))
	assert_near(float(audio.played[1].pitch), 0.25, 0.03, "ralenti ×0,25 : hauteur qui suit")
	p.set_value(ParamIds.TIME_SCALE, 0.05)
	audio.on_events(_contact(25.0, "smash"), _state(600))
	assert_true(float(audio.played[2].pitch) >= MatchAudio.MIN_PITCH - 1e-6, "hauteur jamais sous 0,25")
	p.set_value(ParamIds.AUDIO_SLOWMO_PITCH, 0.0)
	audio.on_events(_contact(25.0, "smash"), _state(900))
	assert_near(float(audio.played[3].pitch), 1.0, 0.05, "réglage coupé : hauteur normale au ralenti")
	p.set_value(ParamIds.AUDIO_ENABLED, 0.0)
	audio.on_events(_contact(25.0, "smash"), _state(1200))
	assert_eq(audio.played.size(), 4, "son désactivé : rien")
	audio.reset()
	assert_eq(audio.played.size(), 0, "relance du match : file vidée")
	_done(audio)


func test_audio_does_not_change_the_simulation() -> void:
	var lineup := MatchConfig.default_lineup(SimHelpers.data().characters)
	var a := MatchSim.new(SimHelpers.fresh_params(), 3, 1.0 / 120.0, lineup, -1)
	var b := MatchSim.new(SimHelpers.fresh_params(), 3, 1.0 / 120.0, lineup, -1)
	var ai_a := AiDirector.new(a.params, 3, 1.0 / 120.0, -1)
	var ai_b := AiDirector.new(b.params, 3, 1.0 / 120.0, -1)
	ai_a.set_lineup(lineup)
	ai_b.set_lineup(lineup)
	var audio := _audio(a.params)
	var fx := ImpactFx.new(a.params)
	for i in 3000:
		var events := a.tick(ai_a.intents(a.state()))
		audio.on_events(events, a.state())
		fx.on_state(a.state())
		fx.on_events(events, a.state())
		b.tick(ai_b.intents(b.state()))
	assert_true(audio.played.size() > 0, "des services ont été sonorisés (%d)" % audio.played.size())
	assert_eq(a.state().fingerprint(), b.state().fingerprint(), "même empreinte avec et sans effets ni son")
	_done(audio)
