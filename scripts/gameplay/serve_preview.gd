class_name ServePreview
extends RefCounted
## Prévision du service pour le joueur humain : arc du lancer, point de frappe en l'air, trajectoire après
## la frappe et zone d'atterrissage. Fonction pure de l'état courant : elle rejoue le ballon avec
## la MÊME physique (`BallBody.step`) et la MÊME formule de contact (`ContactResolver.plan_contact`)
## que la simulation, sans bruit ni hasard. La dispersion est donnée par ± 1 écart-type d'angle.
## Hypothèse : avant le saut, le meilleur saut possible ; en l'air, « tu frappes maintenant ».

const SAMPLE_EVERY_TOSS := 4
const SAMPLE_EVERY_FLIGHT := 6
const MAX_SECONDS := 4.0

## Vrai si une frappe est possible (le ballon passe dans la zone pendant la fenêtre).
var can_hit := false
## Avant le saut (tenue ou lancer) : la frappe affichée est celle du meilleur saut possible.
var planned := true
## Charge du lancer (0 à 1) pendant la tenue du ballon.
var charge := 0.0
var toss_path := PackedVector2Array()
var hit_ball := Vector2.ZERO
var zone_center := Vector2.ZERO
var zone_radius := 0.0
var quality := 0.0
var flight_path := PackedVector2Array()
var landing_x := 0.0
var landing_min := 0.0
var landing_max := 0.0
## Le ballon passe au-dessus du filet.
var clears_net := true
## Atterrit dans le camp adverse (dans les lignes).
var lands_in := false
## Sommet de l'arc du lancer.
var apex_point := Vector2.ZERO
## Partie de l'arc où le ballon est à une hauteur que le serveur peut atteindre (du sol au meilleur saut) : zone de
## frappe POTENTIELLE. Elle ne promet aucun contact : la simulation décide à la frappe.
var reach_path := PackedVector2Array()
## Hauteurs (m) de la bande atteignable : bas = frappe au sol, haut = frappe au sommet du meilleur saut.
var reach_low := 0.0
var reach_high := 0.0


## Prévision pour le serveur `server` ; null s'il n'est pas en train de servir.
## Tenue : arc du lancer pour la charge actuelle. Lancer : trajectoire du ballon. Les deux supposent le
## meilleur saut possible. En l'air : hypothèse « tu frappes maintenant ».
static func compute(server: PlayerActor, ctx: SimContext) -> ServePreview:
	var state := server.state
	if not (state == Enums.ActionState.SERVE_HOLD or state == Enums.ActionState.SERVE_TOSS or state == Enums.ActionState.SERVE_JUMP):
		return null
	var p := ctx.params
	if state != Enums.ActionState.SERVE_HOLD and server.since_toss > p.get_value(ParamIds.PREVIEW_AFTER_TOSS_S):
		return null   # la prévision a fait son temps (réglage d'affichage)
	var out := ServePreview.new()
	out.planned = state != Enums.ActionState.SERVE_JUMP
	var spec := ContactSpec.of(ContactSpec.SERVE, p)
	out.zone_radius = spec.radius
	var g: float = p.get_value(ParamIds.BALL_GRAVITY)
	var drag: float = p.get_value(ParamIds.AIR_DRAG)
	var dt := ctx.dt
	var ball := BallBody.new()
	ball.radius = ctx.ball.radius
	if state == Enums.ActionState.SERVE_HOLD:
		ball.position = server.serve_hold_position(p)
		ball.velocity = server.toss_velocity(p)
		out.charge = server.serve_charge(p)
	else:
		ball.position = ctx.ball.position
		ball.velocity = ctx.ball.velocity
	var balls := PackedVector2Array([ball.position])
	var stop_y := ball.position.y if state == Enums.ActionState.SERVE_HOLD else ball.radius
	for i in int(MAX_SECONDS / dt):
		ball.step(dt, g, drag)
		balls.append(ball.position)
		if ball.velocity.y < 0.0 and ball.position.y <= stop_y:
			break
	for i in range(0, balls.size(), SAMPLE_EVERY_TOSS):
		out.toss_path.append(balls[i])
	out.apex_point = balls[0]
	for b in balls:
		if b.y > out.apex_point.y:
			out.apex_point = b
	out.reach_low = spec.dy - spec.radius
	out.reach_high = spec.dy + StatConversion.jump_apex(server.character.stats, p) + spec.radius
	for pt in out.toss_path:
		if pt.y >= out.reach_low and pt.y <= out.reach_high:
			out.reach_path.append(pt)
	var gp: float = p.get_value(ParamIds.PLAYER_GRAVITY)
	var x := server.body.position.x
	var feet_y := server.body.position.y
	var vy := server.body.velocity.y
	var start := 0   # premier pas où le serveur est (ou sera) en l'air
	if out.planned:
		# Meilleur saut : le sommet du saut tombe quand le ballon descend à la hauteur de la zone au sommet.
		var apex := StatConversion.jump_apex(server.character.stats, p)
		vy = sqrt(2.0 * gp * apex)
		var reach := spec.dy + apex
		var meet := balls.size() - 1
		for i in range(1, balls.size()):
			if balls[i].y < balls[i - 1].y and balls[i].y <= reach:
				meet = i
				break
		start = maxi(0, meet - int(roundf(vy / gp / dt)))
		feet_y = 0.0
	var x_hit := x
	var index := -1
	var elapsed := spec.ideal
	var distance := INF
	if out.planned:
		# Le serveur se replace sous le ballon (vitesse réduite pendant le lancer), sans passer la ligne de fond.
		var walk := StatConversion.run_speed(server.character.stats, p) * p.get_value(ParamIds.SERVE_TOSS_MOVE_FACTOR)
		var line := -server.facing * ctx.court.half_length
		for i in range(start, balls.size()):
			var t := (i - start) * dt
			var y := maxf(0.0, vy * t - 0.5 * gp * t * t)
			var wanted := balls[i].x - server.facing * spec.dx
			var px := clampf(wanted, x - walk * i * dt, x + walk * i * dt)
			px = minf(px, line) if server.facing > 0 else maxf(px, line)
			var d := balls[i].distance_to(spec.center(Vector2(px, y), server.facing))
			if d < distance:
				distance = d
				index = i
				x_hit = px
		out.can_hit = index >= 0 and distance <= spec.radius
	else:
		var first := ceili(spec.t_on / dt)
		var last := mini(floori(spec.t_off / dt), balls.size() - 1)
		var previous := INF
		for i in range(first, last + 1):
			var t := i * dt
			var y := maxf(0.0, feet_y + vy * t - 0.5 * gp * t * t)
			var d := balls[i].distance_to(spec.center(Vector2(x, y), server.facing))
			if d <= spec.radius:
				if d < distance:
					distance = d
					index = i
					elapsed = t
				elif d > previous:
					break   # le ballon s'éloigne : la simulation valide le contact ici
			elif index >= 0:
				break
			previous = d
		out.can_hit = index >= 0
	if index < 0 or not out.can_hit:
		out.can_hit = false
		return out
	var t_hit := (index - start) * dt if out.planned else index * dt
	var y_hit := maxf(0.0, feet_y + vy * t_hit - 0.5 * gp * t_hit * t_hit) if (not out.planned or index >= start) else 0.0
	out.hit_ball = balls[index]
	out.zone_center = spec.center(Vector2(x_hit, y_hit), server.facing)
	var aim := server.aim_axis() * server.facing
	var plan := ContactResolver.plan_contact(spec, server, ctx, balls[index], elapsed, distance, aim, 0.0, y_hit)
	out.quality = plan.q
	var sigma := ContactResolver.noise_sigma(ContactSpec.SERVE, server, p)
	var flight := _fly(ctx, balls[index], plan.speed, plan.angle, server.facing, true)
	out.flight_path = flight.path
	out.landing_x = flight.x
	out.clears_net = flight.clears
	var low := _fly(ctx, balls[index], plan.speed, plan.angle - sigma, server.facing, false)
	var high := _fly(ctx, balls[index], plan.speed, plan.angle + sigma, server.facing, false)
	out.landing_min = minf(low.x, high.x)
	out.landing_max = maxf(low.x, high.x)
	out.lands_in = out.clears_net and flight.x * server.facing > 0.0 and absf(flight.x) <= ctx.court.half_length
	return out


## Vol libre après la frappe jusqu'au sol (ou au filet). Renvoie {path, x, clears}.
static func _fly(ctx: SimContext, from: Vector2, speed: float, angle: float, facing: int, record: bool) -> Dictionary:
	var p := ctx.params
	var g: float = p.get_value(ParamIds.BALL_GRAVITY)
	var drag: float = p.get_value(ParamIds.AIR_DRAG)
	var ball := BallBody.new()
	ball.radius = ctx.ball.radius
	ball.position = from
	ball.velocity = ContactModel.exit_velocity(speed, angle, facing)
	var path := PackedVector2Array([from])
	var clears := true
	var top := ctx.court.net_height + ball.radius
	var steps := int(MAX_SECONDS / ctx.dt)
	for i in steps:
		var before := ball.position
		ball.step(ctx.dt, g, drag)
		if before.x * ball.position.x <= 0.0 and before.x != ball.position.x:
			var f := absf(before.x) / absf(ball.position.x - before.x)
			if lerpf(before.y, ball.position.y, f) < top:
				clears = false
				ball.position = Vector2(0.0, lerpf(before.y, ball.position.y, f))
				if record:
					path.append(ball.position)
				return {"path": path, "x": 0.0, "clears": false}
		if record and i % SAMPLE_EVERY_FLIGHT == 0:
			path.append(ball.position)
		if ball.position.y <= ball.radius and ball.velocity.y < 0.0:
			var f2 := (before.y - ball.radius) / maxf(before.y - ball.position.y, 1e-9)
			var x := lerpf(before.x, ball.position.x, clampf(f2, 0.0, 1.0))
			if record:
				path.append(Vector2(x, ball.radius))
			return {"path": path, "x": x, "clears": clears}
	return {"path": path, "x": ball.position.x, "clears": clears}
