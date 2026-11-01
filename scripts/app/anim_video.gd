class_name AnimVideo
extends Node
## Vidéos de référence des animations de service (dossier de transmission ANIMATION_HANDOFF.md).
## `-- --anim-video TYPE VUE` avec TYPE = sol | flottant | smash et VUE = normal | debug, à lancer avec
## `--write-movie FICHIER.avi --fixed-fps 60` : le service scripté (même scénario que les captures, simulateur réel,
## graine fixe) est joué à vitesse normale (2 ticks par image), puis rejoué au ralenti ×0,25 (1 tick toutes les
## 2 images) avec un arrêt de 0,5 s sur le tick du contact physique. Un bandeau indique le tick, l'état du serveur,
## le clip, son temps et le tick du contact. Vue debug : squelette, pivots, zones de contact, nom du clip.
## Outil de vérification uniquement : il n'écrit rien dans la simulation (il fournit les mêmes entrées qu'un joueur).

const FREEZE_FRAMES := 30
const SLOW_FRAMES_PER_TICK := 2

var runner: MatchRunner
var _driver: FxCapture
var _label: Label
var _contact := -1


func _init(match_runner: MatchRunner) -> void:
	runner = match_runner


func record(kind: String, view_mode: String) -> void:
	var params := runner.data.params
	params.set_value(ParamIds.FX_ENABLED, 0.0)          # vidéo d'animation : sans anneaux ni traînée sur la main
	params.set_value(ParamIds.AUDIO_ENABLED, 0.0)
	params.set_value(ParamIds.PREVIEW_VISIBLE, 0.0)
	params.set_value(ParamIds.PREVIEW_RALLY_MODE, 0.0)
	_driver = FxCapture.new(runner)
	add_child(_driver)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(12, 300)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(_label)
	var script: Array = FxCapture.SCRIPTS[kind]
	var debug := view_mode == "debug"
	for slow in [false, true]:
		var speed_text := "ralenti ×0,25" if slow else "vitesse normale"
		var counter := [0]
		var pace := func(tick: int) -> void:
			runner.view.show_skeleton = debug
			runner.view.show_pivots = debug
			runner.view.show_zones = debug
			runner.view.show_anim_info = debug
			counter[0] += 1
			var frames := SLOW_FRAMES_PER_TICK if slow else (1 if counter[0] % 2 == 0 else 0)
			var at_contact := _driver.contact_tick() == tick and tick >= 0
			if at_contact:
				_contact = tick
				if slow:
					frames += FREEZE_FRAMES
			_update_label(kind, view_mode, speed_text, tick, at_contact)
			for f in frames:
				runner.view.show_states(runner.previous_state, runner.current_state, 1.0)
				await get_tree().process_frame
		await _driver.play(script, pace, 150)
		for f in 20:
			await get_tree().process_frame
	get_tree().quit()


func _update_label(kind: String, view_mode: String, speed_text: String, tick: int, at_contact: bool) -> void:
	var server := runner.current_state.server_slot
	var snap := runner.current_state.players[server]
	var frame: AnimFrame = runner.view.frames[server] if server < runner.view.frames.size() else null
	var clip := "%s  t=%.3f s / %.2f s" % [frame.clip_id, frame.clip_time, frame.duration] if frame != null else "?"
	var contact := "contact physique : à venir"
	if _contact >= 0:
		contact = "contact physique : tick %d (%+d ticks)" % [_contact, tick - _contact]
	if at_contact:
		contact = ">>> CONTACT PHYSIQUE : tick %d <<<" % tick
	_label.text = "Service %s · vue %s · %s\ntick %d · état %s · intention %s · type réel %s\nclip %s\n%s" % [
		kind, view_mode, speed_text, tick, Enums.action_to_string(snap.action), snap.serve_intent,
		snap.strike_kind if snap.strike_kind != "" else "—", clip, contact]
	_label.add_theme_color_override("font_color", Color("ff6b5e") if at_contact else Color.WHITE)
