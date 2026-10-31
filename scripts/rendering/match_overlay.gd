class_name MatchOverlay
extends Node2D
## Couche dessinée AU-DESSUS des mannequins : zones de contact, ballon, indicateur du joueur contrôlé,
## noms d'état, tableau de score et outils de debug du rig (squelette, pivots, animation active).

const COLOR_BALL := Color("f6f1de")
const COLOR_BALL_EDGE := Color("1a1a1a")
const COLOR_ZONE := Color(1.0, 0.81, 0.24)
const COLOR_HUMAN := Color("ffcf3c")
const COLOR_BONE := Color("7be0a8")
const COLOR_PIVOT := Color("ff5a7a")
const COLOR_PREVIEW_OK := Color("7be0a8")
const COLOR_PREVIEW_BAD := Color("ff6b5e")

var view: MatchView


func _draw() -> void:
	if view == null or view.current_state == null:
		return
	var state := view.current_state
	var k := view.pixels_per_meter()
	for i in state.players.size():
		_draw_player_marks(i, state.players[i], k)
	if state.ball_prediction != null:
		_draw_ball_prediction(state.ball_prediction)
	if state.serve_preview != null:
		_draw_serve_preview(state.serve_preview, k)
	if view.fx_enabled():
		_draw_trail()
	_draw_ball(k)
	if view.fx_enabled():
		_draw_impacts(k)
	_draw_scoreboard(get_viewport_rect().size)
	if view.preview_clip != null:
		_draw_preview_info()


func _draw_player_marks(i: int, now: PlayerSnapshot, k: float) -> void:
	var feet := view.to_screen(view.player_position(i))
	var shift := view.player_position(i) - now.position
	var height := 1.8 * k
	if i < view.animators.size():
		height = view.animators[i].dims.standing_height() * k
	if now.slot == view.current_state.human_slot:   # indicateur du joueur contrôlé, indépendant du corps
		var tip := feet + Vector2(0, -height - 18.0)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-7, -12), tip + Vector2(7, -12)]), COLOR_HUMAN)
	draw_string(view.font, feet + Vector2(-30.0, 18.0), Enums.action_to_string(now.action), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
	if view.show_zones:
		_draw_zone(now.receive_center + shift, now.receive_radius, k, false)
		_draw_zone(now.spike_center + shift, now.spike_radius, k, false)
	if now.active_kind != "":
		_draw_zone(now.active_center + shift, now.active_radius, k, true)
	if i < view.rigs.size():
		_draw_rig_debug(view.rigs[i], view.frames[i], feet + Vector2(-34.0, -height - 34.0))


func _draw_rig_debug(rig: MannequinRig, frame: AnimFrame, label_pos: Vector2) -> void:
	if view.show_skeleton:
		for bone_name in RigDef.BONES:
			if bone_name == "root":
				continue
			draw_line(rig.bone_position(bone_name), rig.bone_tip(bone_name), COLOR_BONE, 2.0)
	if view.show_pivots:
		for bone_name in RigDef.BONES:
			draw_circle(rig.bone_position(bone_name), 3.5, COLOR_PIVOT)
	if view.show_anim_info and frame != null:
		var text := "%s · %s\n%.2f / %.2f s (%d %%)" % [frame.clip_id, frame.domain, frame.clip_time, frame.duration, roundi(frame.progress() * 100.0)]
		if frame.blend < 1.0:
			text += " fondu %d %%" % roundi(frame.blend * 100.0)
		draw_multiline_string(view.font, label_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, -1, Color(0.75, 1.0, 0.85))


func _draw_preview_info() -> void:
	var f := view.preview_frame
	if f == null:
		return
	if view.show_skeleton or view.show_pivots:
		_draw_rig_debug(view.preview_rig, f, view.to_screen(Vector2(MatchView.PREVIEW_X_M - 0.6, 3.3)))
	var base := view.to_screen(Vector2(MatchView.PREVIEW_X_M, 0.0)) + Vector2(-90.0, 24.0)
	var text := "TEST D'ANIMATION : %s (%s)\n%.2f / %.2f s · %d %% · ×%.2f%s" % [f.clip_id, f.action, f.clip_time, f.duration,
		roundi(f.progress() * 100.0), view.preview_speed, "" if view.preview_playing else " · pause"]
	draw_multiline_string(view.font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, -1, Color(0.75, 1.0, 0.85))


## Trajectoire prévue du ballon, en transparence, tout le temps : points pâles et anneau là où il retombe
## (vert = dans les lignes, orange = dehors, rouge = s'arrête dans le filet).
func _draw_ball_prediction(pred: BallPrediction) -> void:
	_draw_dotted(pred.path, Color(1, 1, 1, 0.22), 2.0)
	var color := COLOR_PREVIEW_OK if pred.lands_inside else COLOR_PREVIEW_BAD
	var end := view.to_screen(pred.path[pred.path.size() - 1])
	if pred.hits_net:
		draw_line(end + Vector2(-7, -7), end + Vector2(7, 7), Color(color, 0.8), 3.0)
		draw_line(end + Vector2(-7, 7), end + Vector2(7, -7), Color(color, 0.8), 3.0)
		return
	var ground := view.to_screen(Vector2(pred.landing_x, 0.0))
	draw_arc(ground, 11.0, 0.0, TAU, 24, Color(color, 0.7), 3.0, true)
	draw_circle(ground, 4.0, Color(color, 0.45))


## Prévision du service : arc du lancer (points blancs), zone et point de frappe, trajectoire
## après la frappe (verte si elle passe le filet, rouge sinon) et zone d'atterrissage (± 1 écart-type).
func _draw_serve_preview(pv: ServePreview, k: float) -> void:
	var params := view.params
	var opacity := 0.6
	var tint := Color.WHITE
	var shown := true
	if params != null:
		opacity = params.get_value(ParamIds.PREVIEW_OPACITY)
		tint = Color.from_hsv(params.get_value(ParamIds.PREVIEW_HUE), params.get_value(ParamIds.PREVIEW_SATURATION), 1.0)
		shown = params.get_value(ParamIds.PREVIEW_VISIBLE) >= 0.5
	if shown:
		_draw_toss_arc(pv, k, tint, opacity)
	if pv.charge > 0.0 and pv.toss_path.size() > 0:
		var base := view.to_screen(pv.toss_path[0]) + Vector2(-26.0, 22.0)
		draw_rect(Rect2(base, Vector2(52.0, 6.0)), Color(1, 1, 1, 0.2))
		draw_rect(Rect2(base, Vector2(52.0 * pv.charge, 6.0)), COLOR_HUMAN)
	if not shown:
		return
	if not pv.can_hit:
		var hint := view.to_screen(pv.toss_path[pv.toss_path.size() / 2]) if pv.toss_path.size() > 0 else Vector2.ZERO
		draw_string(view.font, hint + Vector2(14, 0), "hors de portée", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.55, 0.5))
		return
	var good := pv.lands_in
	var color := COLOR_PREVIEW_OK if good else COLOR_PREVIEW_BAD
	_draw_zone(pv.zone_center, pv.zone_radius, k, true)
	var hit := view.to_screen(pv.hit_ball)
	draw_arc(hit, maxf(4.0, 0.105 * k), 0.0, TAU, 16, Color.WHITE, 1.5, true)
	_draw_dotted(pv.flight_path, color, 3.0)
	var ground := view.to_screen(Vector2(pv.landing_min, 0.0))
	var ground_end := view.to_screen(Vector2(pv.landing_max, 0.0))
	draw_line(ground, ground_end, Color(color, 0.85), 5.0)
	draw_circle(view.to_screen(Vector2(pv.landing_x, 0.0)), 6.0, color)
	var text := "qualité %d %%" % roundi(pv.quality * 100.0)
	if pv.planned:
		text = "meilleur saut : " + text
	if not pv.clears_net:
		text += " · FILET"
	elif not pv.lands_in:
		text += " · HORS TERRAIN"
	draw_string(view.font, hit + Vector2(16, -10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)


## Arc du lancer : départ, montée (plus marquée), sommet, descente (plus pâle) et bande de frappe POTENTIELLE
## (hauteurs atteignables du sol au meilleur saut). Elle n'annonce pas un contact : la simulation le décide.
func _draw_toss_arc(pv: ServePreview, k: float, tint: Color, opacity: float) -> void:
	if pv.toss_path.size() < 2:
		return
	var apex_index := 0
	for i in pv.toss_path.size():
		if pv.toss_path[i].y >= pv.toss_path[apex_index].y:
			apex_index = i
	for i in pv.toss_path.size():
		var rising := i <= apex_index
		draw_circle(view.to_screen(pv.toss_path[i]), 2.5 if rising else 2.0, Color(tint, opacity * (0.95 if rising else 0.6)))
	for point in pv.reach_path:   # bande de frappe potentielle
		draw_circle(view.to_screen(point), 6.0, Color(COLOR_ZONE, 0.28 * opacity))
	var start := view.to_screen(pv.toss_path[0])
	draw_arc(start, 7.0, 0.0, TAU, 16, Color(tint, opacity), 2.0, true)
	var top := view.to_screen(pv.apex_point)
	draw_colored_polygon(PackedVector2Array([top + Vector2(0, -7), top + Vector2(6, 0), top + Vector2(0, 7), top + Vector2(-6, 0)]), Color(tint, opacity))
	draw_string(view.font, top + Vector2(10, -6), "sommet %.1f m" % pv.apex_point.y, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(tint, opacity))
	if pv.reach_path.size() > 0:
		var mid := view.to_screen(pv.reach_path[pv.reach_path.size() / 2])
		draw_string(view.font, mid + Vector2(-110, 4), "frappe possible", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(COLOR_ZONE, 0.85 * opacity))


## Traînée du ballon : plus rapide, plus épaisse et plus marquée ; elle s'efface avec le temps de simulation.
func _draw_trail() -> void:
	var trail_s: float = view.params.get_value(ParamIds.FX_TRAIL_S) if view.params != null else 0.4
	if trail_s <= 0.0 or view.fx.trail.size() < 2:
		return
	var now := view.fx_time()
	for i in range(1, view.fx.trail.size()):
		var a: Dictionary = view.fx.trail[i - 1]
		var b: Dictionary = view.fx.trail[i]
		var strength := ImpactFx.trail_strength(float(b.v))
		var fade := clampf(1.0 - (now - float(b.t)) / trail_s, 0.0, 1.0)
		if strength <= 0.0 or fade <= 0.0:
			continue
		var color := Color(1, 1, 1).lerp(Color("ff9a3c"), strength)
		draw_line(view.to_screen(a.p), view.to_screen(b.p), Color(color, 0.7 * fade * strength), ImpactFx.trail_width(float(b.v), 5.0), true)


## Impacts : anneau et étincelles proportionnels à la vitesse (double anneau pour un smash), indicateur de vitesse.
func _draw_impacts(k: float) -> void:
	var now := view.fx_time()
	var scale: float = view.params.get_value(ParamIds.FX_IMPACT_SCALE) if view.params != null else 1.0
	var show_speed := view.params == null or view.params.get_value(ParamIds.FX_SPEED_INDICATOR) >= 0.5
	for fx in view.fx.impacts:
		var color := Color("ffffff").lerp(Color("ff7a3c"), fx.weight)
		if fx.serve_kind == "float":
			color = Color("ffe27a")
		var center := view.to_screen(fx.position)
		var p := ImpactFx.impact_progress(fx, now)
		if p >= 0.0:
			var radius := (0.25 + 0.55 * fx.weight) * scale * k * (0.25 + p)
			draw_arc(center, radius, 0.0, TAU, 28, Color(color, 1.0 - p), 3.0, true)
			if fx.serve_kind == "smash":
				draw_arc(center, radius * 0.6, 0.0, TAU, 24, Color(color, 1.0 - p), 2.0, true)
			var sparks := 6 + int(8.0 * fx.weight)
			for i in sparks:
				var angle := TAU * float(i) / float(sparks) + fx.direction.angle()
				var dir := Vector2(cos(angle), -sin(angle))
				draw_line(center + dir * radius * 0.7, center + dir * radius * (1.0 + 0.5 * fx.weight), Color(color, 1.0 - p), 2.0)
		var age := now - fx.born
		if show_speed and fx.action != "" and fx.action != "set" and fx.action != "receive" and age >= 0.0 and age <= ImpactFx.SPEED_LABEL_LIFE_S:
			var fade := 1.0 - age / ImpactFx.SPEED_LABEL_LIFE_S
			draw_string(view.font, center + Vector2(18, -44 - 14 * age), "%d km/h" % roundi(fx.speed * ImpactFx.MS_TO_KMH),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(color, fade))


func _draw_dotted(path: PackedVector2Array, color: Color, radius: float) -> void:
	for point in path:
		draw_circle(view.to_screen(point), radius, color)


func _draw_ball(k: float) -> void:
	var s := view.current_state
	var pos := s.ball_position
	if view.previous_state != null and not s.ball_held:
		pos = view.previous_state.ball_position.lerp(s.ball_position, view.alpha)
	var c := view.to_screen(pos)
	var r := maxf(3.0, s.ball_radius * k)
	draw_circle(c, r, COLOR_BALL)
	draw_arc(c, r, 0.0, TAU, 24, COLOR_BALL_EDGE, 1.5, true)


func _draw_zone(center: Vector2, radius: float, k: float, active: bool) -> void:
	var c := view.to_screen(center)
	if active:
		draw_circle(c, radius * k, Color(COLOR_ZONE, 0.18))
	draw_arc(c, radius * k, 0.0, TAU, 40, Color(COLOR_ZONE, 0.9 if active else 0.3), 2.0 if active else 1.0, true)


func _draw_scoreboard(size: Vector2) -> void:
	var s := view.current_state
	if s.players.size() < 6:
		return
	var font := view.font
	var team: Array[Color] = MatchView.COLOR_TEAM
	var center_x := size.x * 0.5
	draw_string(font, Vector2(center_x - 120, 40), "BLEU %d" % s.score[0], HORIZONTAL_ALIGNMENT_RIGHT, 100, 28, team[0])
	draw_string(font, Vector2(center_x - 8, 40), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	draw_string(font, Vector2(center_x + 22, 40), "%d ROUGE" % s.score[1], HORIZONTAL_ALIGNMENT_LEFT, 120, 28, team[1])
	var serve_x := center_x - 150.0 if s.serving_team == 0 else center_x + 150.0
	draw_circle(Vector2(serve_x, 30), 6.0, COLOR_BALL)
	var info := "%s · touches %d | %d" % [Enums.phase_to_string(s.phase), s.touches[0], s.touches[1]]
	if s.phase == Enums.Phase.POINT_AWARDED and s.point_winner >= 0:
		info = "Point %s : %s" % ["BLEU" if s.point_winner == 0 else "ROUGE", s.fault_text]
	if s.phase == Enums.Phase.MATCH_OVER:
		info = "VICTOIRE %s — R pour rejouer" % ("BLEU" if s.winner == 0 else "ROUGE")
	draw_string(font, Vector2(center_x - 200, 66), info, HORIZONTAL_ALIGNMENT_CENTER, 400, 16, Color(1, 1, 1, 0.8))
