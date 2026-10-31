class_name FxCapture
extends Node
## Outils de vérification des effets et du son de service (J4.1 SJ2), avec le VRAI simulateur et des services scriptés
## (déterministes, graine ServiceCapture.SEED) :
##   `-- --capture-fx DOSSIER` : vignettes larges autour de chaque frappe, effets activés puis désactivés, et contrôle au
##       pixel que le ballon reste visible à chaque tick suivant l'impact (rapport `visibilite_ballon.txt`) ;
##   `-- --demo-fx` (avec `--write-movie FICHIER.avi --fixed-fps 60`) : démonstration enregistrée avec le son mixé :
##       chaque service à vitesse normale, le smash au ralenti ×0,25, puis le smash sans effets ni son.
## Les planches sont assemblées par `tools/fx_sheets.py`.

## Scénarios : [ticks de maintien de L, tick du saut (Espace) ou −1, tick de la frappe (L)], comptés après le lancer.
const SCRIPTS := {"sol": [0, -1, 18], "flottant": [0, 40, 42], "smash": [150, 12, 30], "smash_rate": [150, 20, 58]}
const OFFSETS: Array[int] = [0, 4, 12, 24]
## Vignette : de x0 à x1 (m), de y0 à y1 (m).
const CROP := Rect2(-10.5, -0.5, 10.0, 5.2)
const COLOR_TOLERANCE := 0.12

var runner: MatchRunner
var label: Label
var _contact_tick := -1


func _init(match_runner: MatchRunner) -> void:
	runner = match_runner


## Joue un service scripté ; `on_tick` est attendu après chaque tick (reçoit le tick courant).
func play(script: Array, on_tick: Callable, tail_ticks := 160) -> void:
	runner.human_slot = 0
	runner.restart(ServiceCapture.SEED)
	runner.set_paused(true)
	runner.audio.set_paused(false)   # la pause ne sert qu'à piloter les ticks à la main : le son, lui, joue
	runner.view.show_skeleton = false
	runner.view.show_pivots = false
	runner.view.show_zones = false
	var debug_layer := runner.get_node_or_null("DebugLayer") as CanvasLayer
	if debug_layer != null:
		debug_layer.visible = false   # captures et vidéo sans le texte d'aide ni le diagnostic
	_contact_tick = -1
	var server := runner.sim.ctx.rally.server_slot
	var step := func(intent: PlayerIntent) -> void:
		var intents := runner.ai.intents(runner.current_state)
		intents[server] = intent
		runner.run_one_tick(intents)
		for e in runner.event_log:
			if e.type == MatchEvent.Type.CONTACT and e.details.get("action", "") == "serve" and _contact_tick < 0:
				_contact_tick = e.tick
	while runner.sim.actors[server].state != Enums.ActionState.SERVE_HOLD:
		step.call(PlayerIntent.make())
		await on_tick.call(runner.current_state.tick)
	step.call(PlayerIntent.make(0, false, false, false, false, true, true))
	await on_tick.call(runner.current_state.tick)
	for i in script[0]:
		step.call(PlayerIntent.make(0, false, false, false, false, false, true))
		await on_tick.call(runner.current_state.tick)
	step.call(PlayerIntent.make())
	await on_tick.call(runner.current_state.tick)
	var i := 0
	while i < 400 and (_contact_tick < 0 or runner.current_state.tick < _contact_tick + tail_ticks):
		var it := PlayerIntent.make(0.0, i == script[1])
		if i == script[2]:
			it = PlayerIntent.make(0, false, false, false, false, true, true)
		step.call(it)
		await on_tick.call(runner.current_state.tick)
		i += 1


func contact_tick() -> int:
	return _contact_tick


# ------------------------------------------------------------------ --capture-fx
func capture(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var params := runner.data.params
	params.set_value(ParamIds.PREVIEW_VISIBLE, 0.0)
	var report := PackedStringArray()
	for kind: String in SCRIPTS:
		var script: Array = SCRIPTS[kind]
		var contact := -1
		await play(script, func(_t: int) -> void: pass, 0)
		contact = _contact_tick
		var detail := ""
		for e in runner.event_log:
			if e.type == MatchEvent.Type.CONTACT and e.tick == contact:
				detail = "%s q=%.2f v=%.1f m/s (%d km/h) intensité=%.2f exceptionnel=%s" % [e.details.serve_kind, e.details.q,
					e.details.speed, roundi(float(e.details.speed) * 3.6),
					HitIntensity.compute(e.details.speed, e.details.q, e.details.serve_kind, params),
					HitIntensity.is_exceptional(e.details.speed, e.details.q, e.details.serve_kind, params)]
		print("contact %s : tick %d, %s" % [kind, contact, detail])
		for fx_on in [true, false]:
			params.set_value(ParamIds.FX_ENABLED, 1.0 if fx_on else 0.0)
			var seen := [0, 0]
			var shoot := func(tick: int) -> void:
				if contact < 0 or tick < contact or tick > contact + 60:
					return
				runner.view.show_states(runner.previous_state, runner.current_state, 1.0)
				await RenderingServer.frame_post_draw
				var image := get_viewport().get_texture().get_image()
				if fx_on:
					seen[1] += 1
					if ball_visible(image, runner.view.overlay.ball_screen()):
						seen[0] += 1
				if OFFSETS.has(tick - contact):
					_crop(image).save_png(dir.path_join("fx_%s_%s_%02d.png" % [kind, "on" if fx_on else "off", tick - contact]))
			await play(script, shoot, 64)
			if fx_on:
				report.append("%s : %s ; ballon visible sur %d / %d ticks après l'impact" % [kind, detail, seen[0], seen[1]])
	params.set_value(ParamIds.FX_ENABLED, 1.0)
	var f := FileAccess.open(dir.path_join("visibilite_ballon.txt"), FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	print("\n".join(report))


func _crop(image: Image) -> Image:
	var a := runner.view.to_screen(Vector2(CROP.position.x, CROP.end.y)) - runner.view.camera_px
	var b := runner.view.to_screen(Vector2(CROP.end.x, CROP.position.y)) - runner.view.camera_px
	var rect := Rect2i(Vector2i(a), Vector2i(b - a)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	return image.get_region(rect)


## Le centre du ballon a bien la couleur du ballon (rien n'est dessiné par-dessus).
static func ball_visible(image: Image, at: Vector2) -> bool:
	var p := Vector2i(at.round())
	if not Rect2i(Vector2i.ZERO, image.get_size()).has_point(p):
		return false
	var c := image.get_pixelv(p)
	var ref := MatchOverlay.COLOR_BALL
	return absf(c.r - ref.r) + absf(c.g - ref.g) + absf(c.b - ref.b) < COLOR_TOLERANCE * 3.0


# ------------------------------------------------------------------ --demo-fx
func demo() -> void:
	var params := runner.data.params
	params.set_value(ParamIds.PREVIEW_VISIBLE, 1.0)
	label = Label.new()
	label.position = Vector2(24, 90)
	label.add_theme_font_size_override("font_size", 26)
	get_parent().add_child(label)
	var segments := [
		["Service au sol — effets et son", "sol", 1.0, true],
		["Service flottant — effets et son", "flottant", 1.0, true],
		["Service smashé réussi — effets et son", "smash", 1.0, true],
		["Service smashé raté (rapide mais imparfait)", "smash_rate", 1.0, true],
		["Service smashé réussi — ralenti ×0,25", "smash", 0.25, true],
		["Service smashé réussi — effets et son DÉSACTIVÉS", "smash", 1.0, false],
	]
	for seg: Array in segments:
		label.text = seg[0]
		params.set_value(ParamIds.TIME_SCALE, seg[2])
		params.set_value(ParamIds.FX_ENABLED, 1.0 if seg[3] else 0.0)
		params.set_value(ParamIds.AUDIO_ENABLED, 1.0 if seg[3] else 0.0)
		var frames_per_tick := roundi(0.5 / float(seg[2])) if float(seg[2]) < 1.0 else 0
		var ticks_per_frame := 2 if frames_per_tick == 0 else 1
		var counter := [0]
		# 60 images/s : 2 ticks par image à vitesse normale (120 ticks/s), 1 tick toutes les 2 images au ralenti ×0,25.
		var pace := func(_t: int) -> void:
			counter[0] += 1
			var wait := frames_per_tick if frames_per_tick > 0 else (1 if counter[0] % ticks_per_frame == 0 else 0)
			for w in wait:
				runner.view.show_states(runner.previous_state, runner.current_state, 1.0)
				await get_tree().process_frame
		await play(SCRIPTS[seg[1]], pace, 150)
		for w in 30:
			await get_tree().process_frame
	params.set_value(ParamIds.TIME_SCALE, 1.0)
	params.set_value(ParamIds.FX_ENABLED, 1.0)
	params.set_value(ParamIds.AUDIO_ENABLED, 1.0)
	get_tree().quit()
