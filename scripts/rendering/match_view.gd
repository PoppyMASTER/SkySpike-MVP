class_name MatchView
extends Node2D
## Dessin du match (J1 : sol, repères et ballon). Lit uniquement MatchState et
## l'alpha d'interpolation fournis par MatchRunner ; n'écrit jamais dans la simulation.

const VISIBLE_WIDTH_M := 22.0
const GROUND_RATIO := 0.82
const COLOR_SKY := Color("0d1726")
const COLOR_GROUND := Color("1f3a4d")
const COLOR_LINE := Color("e8f0f2")
const COLOR_GRID := Color(1, 1, 1, 0.07)
const COLOR_BALL := Color("f6f1de")
const COLOR_BALL_EDGE := Color("1a1a1a")
const COLOR_MARK := Color("ffcf3c")

var previous_state: MatchState
var current_state: MatchState
var alpha := 0.0
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font


## Appelé par MatchRunner à chaque image.
func show_states(previous: MatchState, current: MatchState, render_alpha: float) -> void:
	previous_state = previous
	current_state = current
	alpha = render_alpha
	queue_redraw()


func pixels_per_meter() -> float:
	return get_viewport_rect().size.x / VISIBLE_WIDTH_M


## Mètres (x, y vers le haut) → pixels écran.
func to_screen(world: Vector2) -> Vector2:
	var size := get_viewport_rect().size
	var k := pixels_per_meter()
	return Vector2(size.x * 0.5 + world.x * k, size.y * GROUND_RATIO - world.y * k)


func _draw() -> void:
	var size := get_viewport_rect().size
	var k := pixels_per_meter()
	var ground_y := size.y * GROUND_RATIO
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_SKY)
	draw_rect(Rect2(0, ground_y, size.x, size.y - ground_y), COLOR_GROUND)
	# Graduations : un trait par mètre, chiffres tous les 3 m.
	for m in range(-11, 12):
		var x := to_screen(Vector2(m, 0)).x
		draw_line(Vector2(x, 0), Vector2(x, ground_y), COLOR_GRID, 1.0)
		if m % 3 == 0:
			draw_string(font, Vector2(x + 3, ground_y + 18), "%d m" % m, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.5))
	for h in range(1, 8):
		var y := to_screen(Vector2(0, h)).y
		draw_line(Vector2(0, y), Vector2(size.x, y), COLOR_GRID, 1.0)
	draw_line(Vector2(0, ground_y), Vector2(size.x, ground_y), COLOR_LINE, 2.0)
	# Point de lancer de l'exercice J1.
	var start := to_screen(MatchSim.DRILL_START)
	draw_circle(start, 4.0, COLOR_MARK)
	if current_state == null:
		return
	var pos := current_state.ball_position
	if previous_state != null:
		pos = previous_state.ball_position.lerp(current_state.ball_position, alpha)
	var c := to_screen(pos)
	var r := maxf(3.0, current_state.ball_radius * k)
	draw_circle(c, r, COLOR_BALL)
	draw_arc(c, r, 0.0, TAU, 24, COLOR_BALL_EDGE, 1.5, true)
