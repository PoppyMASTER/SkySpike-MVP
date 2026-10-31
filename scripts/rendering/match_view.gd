class_name MatchView
extends Node2D
## Dessin du match (J3 : terrain, filet, six silhouettes provisoires, zones de contact, ballon, score).
## Lit uniquement MatchState et l'alpha d'interpolation fournis par MatchRunner ; n'écrit jamais
## dans la simulation. Le rig articulé remplacera les silhouettes au J4.

const VISIBLE_WIDTH_M := 22.0
const GROUND_RATIO := 0.82
const COLOR_SKY := Color("0d1726")
const COLOR_GROUND := Color("1f3a4d")
const COLOR_LINE := Color("e8f0f2")
const COLOR_GRID := Color(1, 1, 1, 0.07)
const COLOR_BALL := Color("f6f1de")
const COLOR_BALL_EDGE := Color("1a1a1a")
const COLOR_NET := Color("c9d3d8")
const COLOR_NET_TAPE := Color("ffffff")
const COLOR_BODY := Color("3b4046")
const COLOR_TEAM: Array[Color] = [Color("4f9dde"), Color("e0524f")]   # équipe du joueur = bleu, adverse = rouge
const COLOR_ZONE := Color(1.0, 0.81, 0.24)
const COLOR_HUMAN := Color("ffcf3c")
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
	for m in range(-11, 12):
		var x := to_screen(Vector2(m, 0)).x
		draw_line(Vector2(x, 0), Vector2(x, ground_y), COLOR_GRID, 1.0)
		if m % 3 == 0:
			draw_string(font, Vector2(x + 3, ground_y + 18), "%d m" % m, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.5))
	for h in range(1, 8):
		var y := to_screen(Vector2(0, h)).y
		draw_line(Vector2(0, y), Vector2(size.x, y), COLOR_GRID, 1.0)
	draw_line(Vector2(0, ground_y), Vector2(size.x, ground_y), COLOR_LINE, 2.0)
	if current_state == null:
		return
	_draw_court(k)
	for i in current_state.players.size():
		var before: PlayerSnapshot = previous_state.players[i] if previous_state != null and i < previous_state.players.size() else null
		_draw_player(current_state.players[i], before, k)
	_draw_ball(k)
	_draw_scoreboard(size)


func _draw_court(k: float) -> void:
	var half := current_state.court_half_length
	var ground_y := to_screen(Vector2.ZERO).y
	for side in [-1.0, 1.0]:
		var x := to_screen(Vector2(side * half, 0)).x
		draw_line(Vector2(x, ground_y - 6.0), Vector2(x, ground_y + 6.0), COLOR_LINE, 3.0)
	var top := to_screen(Vector2(0, current_state.net_height)).y
	var half_w := maxf(1.5, current_state.net_half_thickness * k)
	var net_x := to_screen(Vector2.ZERO).x
	draw_rect(Rect2(net_x - half_w, top, half_w * 2.0, ground_y - top), COLOR_NET)
	draw_rect(Rect2(net_x - half_w - 1.0, top, half_w * 2.0 + 2.0, 4.0), COLOR_NET_TAPE)


func _draw_ball(k: float) -> void:
	var pos := current_state.ball_position
	if previous_state != null and not current_state.ball_held:
		pos = previous_state.ball_position.lerp(current_state.ball_position, alpha)
	var c := to_screen(pos)
	var r := maxf(3.0, current_state.ball_radius * k)
	draw_circle(c, r, COLOR_BALL)
	draw_arc(c, r, 0.0, TAU, 24, COLOR_BALL_EDGE, 1.5, true)


func _draw_player(now: PlayerSnapshot, before: PlayerSnapshot, k: float) -> void:
	var pos := now.position if before == null else before.position.lerp(now.position, alpha)
	var shift := pos - now.position
	var feet := to_screen(pos)
	var half_w := PLAYER_HALF_WIDTH_M * k
	var h := PLAYER_HEIGHT_M * k
	var body := Rect2(feet.x - half_w, feet.y - h, half_w * 2.0, h)
	draw_rect(body, COLOR_BODY)
	draw_rect(body, COLOR_TEAM[now.team], false, 2.0)   # liseré d'équipe
	draw_circle(feet + Vector2(now.facing * half_w * 0.5, -h * 0.82), maxf(2.0, 0.05 * k), Color.WHITE)
	if now.slot == current_state.human_slot:   # indicateur du joueur contrôlé, indépendant du corps
		var tip := feet + Vector2(0, -h - 14.0)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-7, -12), tip + Vector2(7, -12)]), COLOR_HUMAN)
	draw_string(font, feet + Vector2(-half_w - 6.0, 18.0), Enums.action_to_string(now.action), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
	if show_zones:
		_draw_zone(now.receive_center + shift, now.receive_radius, k, false)
		_draw_zone(now.spike_center + shift, now.spike_radius, k, false)
	if now.active_kind != "":
		_draw_zone(now.active_center + shift, now.active_radius, k, true)


func _draw_zone(center: Vector2, radius: float, k: float, active: bool) -> void:
	var c := to_screen(center)
	if active:
		draw_circle(c, radius * k, Color(COLOR_ZONE, 0.18))
	draw_arc(c, radius * k, 0.0, TAU, 40, Color(COLOR_ZONE, 0.9 if active else 0.3), 2.0 if active else 1.0, true)


func _draw_scoreboard(size: Vector2) -> void:
	var s := current_state
	if s.players.size() < 6:
		return
	var center_x := size.x * 0.5
	draw_string(font, Vector2(center_x - 120, 40), "BLEU %d" % s.score[0], HORIZONTAL_ALIGNMENT_RIGHT, 100, 28, COLOR_TEAM[0])
	draw_string(font, Vector2(center_x - 8, 40), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	draw_string(font, Vector2(center_x + 22, 40), "%d ROUGE" % s.score[1], HORIZONTAL_ALIGNMENT_LEFT, 120, 28, COLOR_TEAM[1])
	var serve_x := center_x - 150.0 if s.serving_team == 0 else center_x + 150.0
	draw_circle(Vector2(serve_x, 30), 6.0, COLOR_BALL)
	var info := "%s · touches %d | %d" % [Enums.phase_to_string(s.phase), s.touches[0], s.touches[1]]
	if s.phase == Enums.Phase.POINT_AWARDED and s.point_winner >= 0:
		info = "Point %s : %s" % ["BLEU" if s.point_winner == 0 else "ROUGE", s.fault_text]
	if s.phase == Enums.Phase.MATCH_OVER:
		info = "VICTOIRE %s — R pour rejouer" % ("BLEU" if s.winner == 0 else "ROUGE")
	draw_string(font, Vector2(center_x - 200, 66), info, HORIZONTAL_ALIGNMENT_CENTER, 400, 16, Color(1, 1, 1, 0.8))
