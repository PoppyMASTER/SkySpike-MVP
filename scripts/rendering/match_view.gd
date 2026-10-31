class_name MatchView
extends Node2D
## Dessin du match (J2 : sol, filet, lignes, joueur provisoire, zones de contact et ballon). Lit uniquement MatchState et
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
const COLOR_NET := Color("c9d3d8")
const COLOR_NET_TAPE := Color("ffffff")
const COLOR_PLAYER := Color("4f9dde")
const COLOR_PLAYER_AIR := Color("7fc0f0")
const COLOR_ZONE := Color(1.0, 0.81, 0.24)
## Silhouette provisoire (le rig animé arrive au J4) : capsule de 1,8 m.
const PLAYER_HEIGHT_M := 1.8
const PLAYER_HALF_WIDTH_M := 0.25

var previous_state: MatchState
var current_state: MatchState
var alpha := 0.0
var font: Font
## Affiche aussi les zones de contact au repos (touche F2).
var show_zones := false


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
	_draw_court(k)
	for i in current_state.players.size():
		var before: PlayerSnapshot = previous_state.players[i] if previous_state != null and i < previous_state.players.size() else null
		_draw_player(current_state.players[i], before, k)
	var pos := current_state.ball_position
	if previous_state != null:
		pos = previous_state.ball_position.lerp(current_state.ball_position, alpha)
	var c := to_screen(pos)
	var r := maxf(3.0, current_state.ball_radius * k)
	draw_circle(c, r, COLOR_BALL)
	draw_arc(c, r, 0.0, TAU, 24, COLOR_BALL_EDGE, 1.5, true)


func _draw_court(k: float) -> void:
	var half := current_state.court_half_length
	var ground_y := to_screen(Vector2.ZERO).y
	for side in [-1.0, 1.0]:
		var x := to_screen(Vector2(side * half, 0)).x
		draw_line(Vector2(x, ground_y - 6.0), Vector2(x, ground_y + 6.0), COLOR_LINE, 3.0)
	var top := to_screen(Vector2(0, current_state.net_height)).y
	var half_w := maxf(1.5, current_state.net_half_thickness * k)
	draw_rect(Rect2(to_screen(Vector2.ZERO).x - half_w, top, half_w * 2.0, ground_y - top), COLOR_NET)
	draw_rect(Rect2(to_screen(Vector2.ZERO).x - half_w - 1.0, top, half_w * 2.0 + 2.0, 4.0), COLOR_NET_TAPE)


func _draw_player(now: PlayerSnapshot, before: PlayerSnapshot, k: float) -> void:
	var pos := now.position if before == null else before.position.lerp(now.position, alpha)
	var shift := pos - now.position
	var feet := to_screen(pos)
	var half_w := PLAYER_HALF_WIDTH_M * k
	var color := COLOR_PLAYER if now.grounded else COLOR_PLAYER_AIR
	draw_rect(Rect2(feet.x - half_w, feet.y - PLAYER_HEIGHT_M * k, half_w * 2.0, PLAYER_HEIGHT_M * k), color)
	var eye := feet + Vector2(now.facing * half_w * 0.5, -PLAYER_HEIGHT_M * k * 0.82)
	draw_circle(eye, maxf(2.0, 0.05 * k), Color.WHITE)
	var label := Enums.action_to_string(now.action)
	draw_string(font, feet + Vector2(-half_w, -PLAYER_HEIGHT_M * k - 8.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.8))
	_draw_zone(now.receive_center + shift, now.receive_radius, k, now.active_zone == PlayerSnapshot.Zone.RECEIVE)
	_draw_zone(now.spike_center + shift, now.spike_radius, k, now.active_zone == PlayerSnapshot.Zone.SPIKE)


func _draw_zone(center: Vector2, radius: float, k: float, active: bool) -> void:
	if not active and not show_zones:
		return
	var c := to_screen(center)
	if active:
		draw_circle(c, radius * k, Color(COLOR_ZONE, 0.18))
	draw_arc(c, radius * k, 0.0, TAU, 40, Color(COLOR_ZONE, 0.9 if active else 0.3), 2.0 if active else 1.0, true)
