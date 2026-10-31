class_name DiagnosticsOverlay
extends PanelContainer
## Mesures affichées en permanence (coin haut gauche) : FPS, temps de simulation, ticks,
## graine, ballon, derniers événements, erreurs de données. Lecture seule.

const REFRESH_S := 0.1
const EVENTS_SHOWN := 6

var runner: MatchRunner
var _label: Label
var _timer := 0.0


func _ready() -> void:
	runner = owner as MatchRunner
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	add_child(_label)
	position = Vector2(12, 12)


func _process(delta: float) -> void:
	_timer -= delta
	if runner == null or runner.current_state == null or _timer > 0.0:
		return
	_timer = REFRESH_S
	var s := runner.current_state
	var lines := PackedStringArray()
	if runner.data.params.experimental_mode:
		lines.append("⚠ MODE EXPÉRIMENTAL")
	lines.append("FPS %.0f · image %.2f ms" % [runner.fps, runner.frame_ms])
	lines.append("Simulation : %.1f µs / tick · %d tick(s) cette image · %d abandonné(s)" % [
		runner.sim_us_per_tick, runner.ticks_last_frame, runner.clock.dropped_ticks])
	lines.append("Tick %d · %d ticks/s · ×%.2f%s" % [s.tick, roundi(1.0 / runner.clock.dt),
		runner.clock.time_scale, "  [PAUSE]" if runner.is_paused() else ""])
	lines.append("Graine %d" % s.seed_value)
	lines.append("Ballon : x %.2f m, y %.2f m · vx %.2f, vy %.2f m/s" % [
		s.ball_position.x, s.ball_position.y, s.ball_velocity.x, s.ball_velocity.y])
	var errors := GameLog.count(GameLog.Level.ERROR)
	var warnings := GameLog.count(GameLog.Level.WARNING)
	if not s.players.is_empty():
		var pl := s.players[0]
		lines.append("Joueur : x %.2f m, y %.2f m · vx %.2f · %s %.2f s" % [
			pl.position.x, pl.position.y, pl.velocity.x, Enums.action_to_string(pl.action), pl.action_time])
	lines.append("Journal : %d erreur(s), %d avertissement(s)" % [errors, warnings])
	lines.append("Derniers événements :")
	var events := runner.event_log
	for i in range(maxi(0, events.size() - EVENTS_SHOWN), events.size()):
		lines.append("  " + events[i].to_text())
	lines.append("Jouer : ←/→ ou Q/D bouger · Espace sauter, puis Espace = smash · J réception")
	lines.append("F1 panneau · F2 zones · P pause · N un tick · R relancer")
	_label.text = "\n".join(lines)
