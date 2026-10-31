class_name FxOverlay
extends RefCounted
## Dessin des effets de frappe (J4.1 SJ2), appelé par MatchOverlay. Deux passes autour du ballon :
##   1. sous le ballon : traînée (ruban continu), éclair, anneaux, éclats, lignes de vitesse ;
##   2. le ballon (MatchOverlay) puis les étiquettes de vitesse, décalées loin du ballon.
## Le ballon est donc toujours dessiné PAR-DESSUS les effets, et les anneaux s'ouvrent à distance du ballon.
## Couleurs : vert, orange et rouge restent réservés à la prévision (pointillés) ; les effets utilisent blanc, bleu
## clair, cyan, jaune-orangé, et la traînée est un ruban continu (jamais des points).

const COLOR_GROUND := Color("d8eeff")
const COLOR_FLOAT := Color("7fe8ff")
const COLOR_FLOAT_SPARK := Color("e9fbff")
const COLOR_SMASH := Color("ffb347")
const COLOR_SMASH_HOT := Color("ffe066")
const COLOR_GENERIC_FAST := Color("ff9a3c")
const COLOR_DULL := Color("9aa4ad")
## Les anneaux restent au moins à cette distance du centre du ballon (× rayon affiché du ballon).
const BALL_CLEAR := 1.6
## Opacité maximale de l'éclair (dessiné sous le ballon).
const FLASH_MAX_ALPHA := 0.35
const SPEED_LINES := 6


## Couleur d'un impact : teinte du type de frappe, ternie quand la qualité est faible.
static func impact_color(fx: ImpactFx.Impact) -> Color:
	var base := Color.WHITE.lerp(COLOR_GENERIC_FAST, fx.intensity)
	match fx.kind:
		"ground":
			base = COLOR_GROUND
		"float":
			base = COLOR_FLOAT
		"smash":
			base = COLOR_SMASH.lerp(COLOR_SMASH_HOT, fx.intensity)
	return base.lerp(COLOR_DULL, (1.0 - clampf(fx.quality, 0.0, 1.0)) * 0.6)


## Rayon (px) de l'anneau principal à l'avancement `p` : jamais sur le ballon.
static func ring_radius(fx: ImpactFx.Impact, p: float, k: float, scale: float, ball_px: float) -> float:
	var size := float(ImpactFx.KIND_SIZE.get(fx.kind, 1.0))
	return maxf(ball_px * BALL_CLEAR, (0.25 + 0.55 * fx.intensity) * size * scale * k * (0.25 + p))


## Couleur et épaisseur (px) d'un point de traînée.
static func trail_style(point: Dictionary) -> Dictionary:
	var v := float(point.v)
	var i := float(point.i)
	match String(point.k):
		"ground":
			return {"color": COLOR_GROUND, "alpha": 0.45 * (0.4 + 0.6 * i), "width": 3.0}
		"float":
			return {"color": COLOR_FLOAT, "alpha": 0.6 * (0.4 + 0.6 * i), "width": 2.5}
		"smash":
			return {"color": COLOR_SMASH.lerp(COLOR_SMASH_HOT, i), "alpha": 0.75 * (0.35 + 0.65 * i), "width": 6.0 * (0.6 + 0.4 * i)}
	var strength := ImpactFx.trail_strength(v)
	return {"color": Color.WHITE.lerp(COLOR_GENERIC_FAST, strength), "alpha": 0.7 * strength, "width": ImpactFx.trail_width(v, 5.0)}


## Décalage (m) PUREMENT GRAPHIQUE d'un point de la traînée du flottant, perpendiculaire au mouvement. Nul au
## niveau du ballon (la traînée rejoint toujours la vraie position) ; le ballon et la prévision ne bougent pas.
static func wobble(point: Dictionary, now: float, amplitude_m: float, frequency_hz: float) -> float:
	if String(point.k) != "float" or amplitude_m <= 0.0:
		return 0.0
	var age := now - float(point.t)
	var grow := clampf(age / 0.08, 0.0, 1.0)
	return amplitude_m * (0.4 + 0.6 * float(point.i)) * grow * sin(TAU * frequency_hz * (float(point.t) - float(point.c)))


# ------------------------------------------------------------------ passe 1 : sous le ballon
static func draw_under_ball(canvas: CanvasItem, view: MatchView, ball_screen: Vector2, ball_px: float) -> void:
	_draw_trail(canvas, view)
	var params := view.params
	var now := view.fx_time()
	var k := view.pixels_per_meter()
	var scale: float = params.get_value(ParamIds.FX_IMPACT_SCALE)
	for fx in view.fx.impacts:
		var age := now - fx.born
		if age < 0.0:
			continue
		var color := impact_color(fx)
		var center := view.to_screen(fx.position)
		if fx.exceptional and age <= ImpactFx.FLASH_LIFE_S:
			canvas.draw_circle(center, ball_px * 3.0, Color(COLOR_SMASH_HOT, FLASH_MAX_ALPHA * (1.0 - age / ImpactFx.FLASH_LIFE_S)))
		var p := ImpactFx.impact_progress(fx, now)
		if p >= 0.0:
			_draw_ring(canvas, fx, center, ring_radius(fx, p, k, scale, ball_px), p, color)
		if fx.exceptional and params.get_value(ParamIds.FX_SPEED_LINES) >= 0.5 and age <= ImpactFx.SPEED_LINES_LIFE_S:
			_draw_speed_lines(canvas, view, fx, age, ball_screen, ball_px, k)


static func _draw_ring(canvas: CanvasItem, fx: ImpactFx.Impact, center: Vector2, radius: float, p: float, color: Color) -> void:
	var a := 1.0 - p
	var spin := fx.direction.angle()
	match fx.kind:
		"ground":   # léger : un anneau fin, quelques éclats courts
			canvas.draw_arc(center, radius, 0.0, TAU, 28, Color(color, a), 2.0, true)
			_sparks(canvas, center, radius, 4 + int(2.0 * fx.intensity), 0.25 + 0.15 * fx.intensity, spin, Color(color, a), 1.5)
		"float":    # sec : anneau net et éclats droits, sans halo
			canvas.draw_arc(center, radius, 0.0, TAU, 28, Color(color, a), 2.5, true)
			_sparks(canvas, center, radius, 5, 0.5, spin + 0.3, Color(COLOR_FLOAT_SPARK, a), 2.0)
		"smash":    # double anneau, étincelles nombreuses
			canvas.draw_arc(center, radius, 0.0, TAU, 32, Color(color, a), 3.0, true)
			canvas.draw_arc(center, radius * 1.35, 0.0, TAU, 32, Color(color, a * 0.7), 2.0, true)
			_sparks(canvas, center, radius, 10 + int(4.0 * fx.intensity), 0.4 + 0.5 * fx.intensity, spin, Color(color, a), 2.0)
		_:
			canvas.draw_arc(center, radius, 0.0, TAU, 28, Color(color, a), 3.0, true)
			_sparks(canvas, center, radius, 6 + int(8.0 * fx.intensity), 0.5 * fx.intensity + 0.3, spin, Color(color, a), 2.0)


static func _sparks(canvas: CanvasItem, center: Vector2, radius: float, count: int, length: float, spin: float, color: Color, width: float) -> void:
	for i in count:
		var angle := TAU * float(i) / float(count) + spin
		var dir := Vector2(cos(angle), -sin(angle))
		canvas.draw_line(center + dir * radius * 0.85, center + dir * radius * (1.0 + length), color, width)


## Lignes de vitesse : derrière le ballon (jamais devant ni dessus), parallèles à son mouvement.
static func _draw_speed_lines(canvas: CanvasItem, view: MatchView, fx: ImpactFx.Impact, age: float, ball_screen: Vector2, ball_px: float, k: float) -> void:
	var vel := view.current_state.ball_velocity
	if view.current_state.ball_held or vel.length() < 0.1:
		return
	var back := -Vector2(vel.x, -vel.y).normalized()
	var side := Vector2(-back.y, back.x)
	var fade := 1.0 - age / ImpactFx.SPEED_LINES_LIFE_S
	var length := (0.5 + 0.8 * fx.intensity) * 0.6 * k
	for i in SPEED_LINES:
		var offset := (float(i) - (SPEED_LINES - 1) * 0.5) * ball_px * 0.55
		var start := ball_screen + back * ball_px * 2.5 + side * offset
		var stretch := length * (0.6 + 0.4 * absf(sin(float(i) * 1.7)))
		canvas.draw_line(start, start + back * stretch, Color(COLOR_SMASH_HOT, 0.55 * fade), 1.5, true)


static func _draw_trail(canvas: CanvasItem, view: MatchView) -> void:
	var trail := view.fx.trail
	if trail.size() < 2:
		return
	var now := view.fx_time()
	var amp: float = view.params.get_value(ParamIds.FX_FLOAT_WOBBLE_M)
	var hz: float = view.params.get_value(ParamIds.FX_FLOAT_WOBBLE_HZ)
	var prev := view.to_screen(_wobbled(trail, 0, now, amp, hz))
	for i in range(1, trail.size()):
		var b: Dictionary = trail[i]
		var here := view.to_screen(_wobbled(trail, i, now, amp, hz))
		var style := trail_style(b)
		var life := float(b.life)
		var fade := clampf(1.0 - (now - float(b.t)) / life, 0.0, 1.0) if life > 0.0 else 0.0
		var alpha := float(style.alpha) * fade
		if alpha > 0.0 and String(b.k) == String(trail[i - 1].k):
			canvas.draw_line(prev, here, Color(style.color, alpha), float(style.width), true)
		prev = here


static func _wobbled(trail: Array[Dictionary], i: int, now: float, amp: float, hz: float) -> Vector2:
	var point: Dictionary = trail[i]
	var offset := wobble(point, now, amp, hz)
	if offset == 0.0:
		return point.p
	var j := mini(i + 1, trail.size() - 1)
	var h := maxi(i - 1, 0)
	var dir := (Vector2(trail[j].p) - Vector2(trail[h].p)).normalized()
	return Vector2(point.p) + Vector2(-dir.y, dir.x) * offset


# ------------------------------------------------------------------ passe 2 : au-dessus du ballon
## Étiquettes de vitesse (km/h), au-dessus et à droite du point d'impact, loin du ballon qui s'éloigne.
static func draw_labels(canvas: CanvasItem, view: MatchView) -> void:
	if view.params.get_value(ParamIds.FX_SPEED_INDICATOR) < 0.5:
		return
	var show_ground := view.params.get_value(ParamIds.FX_SPEED_LABEL_GROUND) >= 0.5
	var now := view.fx_time()
	for fx in view.fx.impacts:
		var age := now - fx.born
		if not label_shown(fx, show_ground) or age < 0.0 or age > ImpactFx.SPEED_LABEL_LIFE_S:
			continue
		var fade := 1.0 - age / ImpactFx.SPEED_LABEL_LIFE_S
		canvas.draw_string(view.font, view.to_screen(fx.position) + Vector2(18, -44 - 14 * age), "%d km/h" % roundi(fx.speed * ImpactFx.MS_TO_KMH),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(impact_color(fx), fade))


static func label_shown(fx: ImpactFx.Impact, show_ground: bool) -> bool:
	if fx.action == "" or fx.action == "set" or fx.action == "receive":
		return false
	return fx.kind != "ground" or show_ground
