class_name ServePreview
extends RefCounted
## Prévision du service pour le joueur humain : arc du lancer, point de frappe, trajectoire après
## la frappe et zone d'atterrissage. Fonction pure de l'état courant : elle rejoue le ballon avec
## la MÊME physique (`BallBody.step`) et la MÊME formule de contact (`ContactResolver.plan_contact`)
## que la simulation, sans bruit ni hasard. La dispersion est donnée par ± 1 écart-type d'angle.
## Hypothèse affichée au joueur : « si tu frappes maintenant » (en tenue : au meilleur moment).

const SAMPLE_EVERY_TOSS := 4
const SAMPLE_EVERY_FLIGHT := 6
const MAX_SECONDS := 4.0

## Vrai si une frappe est possible (le ballon passe dans la zone pendant la fenêtre).
var can_hit := false
## Tenue (SERVE_HOLD) : le lancer n'est pas encore parti, la frappe est celle du meilleur moment.
var holding := false
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


## Prévision pour le serveur `server` ; null s'il n'est pas en train de servir.
static func compute(server: PlayerActor, ctx: SimContext) -> ServePreview:
	var holding := server.state == Enums.ActionState.SERVE_HOLD
	if not (holding or server.state == Enums.ActionState.SERVE_TOSS or server.state == Enums.ActionState.SERVE_JUMP):
		return null
	var p := ctx.params
	var out := ServePreview.new()
	out.holding = holding
	var spec := ContactSpec.of(ContactSpec.SERVE, p)
	out.zone_radius = spec.radius
	var g: float = p.get_value(ParamIds.BALL_GRAVITY)
	var drag: float = p.get_value(ParamIds.AIR_DRAG)
	var dt := ctx.dt
	var ball := BallBody.new()
	ball.radius = ctx.ball.radius
	if holding:
		ball.position = server.serve_hold_position(p)
		ball.velocity = Vector2(server.aim_axis() * p.get_value(ParamIds.SERVE_TOSS_DRIFT), p.get_value(ParamIds.SERVE_TOSS_SPEED))
	else:
		ball.position = ctx.ball.position
		ball.velocity = ctx.ball.velocity
	var balls := PackedVector2Array([ball.position])
	var floor_y := ball.position.y if holding else ball.radius
	var max_steps := int(MAX_SECONDS / dt)
	for i in max_steps:
		ball.step(dt, g, drag)
		balls.append(ball.position)
		if ball.velocity.y < 0.0 and ball.position.y <= (floor_y if holding else ball.radius):
			break
	for i in range(0, balls.size(), SAMPLE_EVERY_TOSS):
		out.toss_path.append(balls[i])
	# Position du joueur à chaque pas (vertical seulement : le serveur reste en place à l'horizontale).
	var feet_y := server.body.position.y
	var vy := server.body.velocity.y
	var gp: float = p.get_value(ParamIds.PLAYER_GRAVITY)
	var airborne := not server.body.grounded
	var index := -1
	var elapsed := 0.0
	var distance := INF
	if holding:
		# Meilleur moment : le ballon au plus près de la zone ; la frappe se déclenche `ideal` avant.
		for i in balls.size():
			var d := balls[i].distance_to(spec.center(server.body.position, server.facing))
			if d < distance:
				distance = d
				index = i
		elapsed = spec.ideal
		out.can_hit = distance <= spec.radius
	else:
		var first := ceili(spec.t_on / dt)
		var last := mini(floori(spec.t_off / dt), balls.size() - 1)
		var previous := INF
		for i in range(first, last + 1):
			var t := i * dt
			var y := maxf(0.0, feet_y + vy * t - 0.5 * gp * t * t) if airborne else feet_y
			var center := spec.center(Vector2(server.body.position.x, y), server.facing)
			var d := balls[i].distance_to(center)
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
	if index < 0:
		return out
	var t_hit := index * dt
	var y_hit := maxf(0.0, feet_y + vy * t_hit - 0.5 * gp * t_hit * t_hit) if (airborne and not holding) else feet_y
	out.hit_ball = balls[index]
	out.zone_center = spec.center(Vector2(server.body.position.x, y_hit), server.facing)
	var aim := server.aim_axis() * server.facing
	var plan := ContactResolver.plan_contact(spec, server, ctx, balls[index], elapsed, distance, aim, 0.0)
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
