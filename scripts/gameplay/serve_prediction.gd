class_name ServePrediction
extends RefCounted
## Intention de frappe du service, partagée entre le gameplay et l'animation : le type de service (sol / flottant /
## smash) que la hauteur des pieds donnera à l'instant où la simulation validera le contact, et l'instant d'état où ce
## contact est attendu. Rejoue le ballon et le saut avec la MÊME physique et la MÊME règle de validation que
## `PlayerActor._update_window`, sans rien modifier. Le type RÉEL est confirmé au contact (`CONTACT.serve_kind`) :
## le résultat physique reste toujours prioritaire. Sans contact prévu (frappe manquée), l'instant idéal est utilisé.


## `elapsed` = temps déjà écoulé depuis l'ouverture de la fenêtre. Renvoie {kind, contact_at}.
static func compute(actor: PlayerActor, ctx: SimContext, elapsed := 0.0) -> Dictionary:
	var p := ctx.params
	var body := actor.body
	var spec := ContactSpec.of(ContactSpec.SERVE, p)
	var gp: float = p.get_value(ParamIds.PLAYER_GRAVITY)
	var ball := BallBody.new()
	ball.radius = ctx.ball.radius
	ball.position = ctx.ball.position
	ball.velocity = ctx.ball.velocity
	var t_commit := maxf(spec.ideal - elapsed, 0.0)
	var best := INF
	var t := 0.0
	while elapsed + t <= spec.t_off + ctx.dt:   # la fenêtre se ferme au tick suivant t_off
		var before := ball.position
		ball.step(ctx.dt, p.get_value(ParamIds.BALL_GRAVITY), p.get_value(ParamIds.AIR_DRAG))
		t += ctx.dt
		if elapsed + t < spec.t_on:
			continue
		var y := _feet(body, gp, t)
		var center := spec.center(Vector2(body.position.x, y), actor.facing)
		var d := SweptCollision.point_segment_distance(center, before, ball.position)
		if d <= spec.radius:
			best = minf(best, d)
			t_commit = t
			if SweptCollision.closest_fraction(center, before, ball.position) < 1.0:
				break   # approche maximale : la simulation valide le contact à ce tick
		elif best < INF:
			break   # le ballon est ressorti de la zone : contact validé à ce tick
	# Le type réel dépend de la hauteur des pieds au tick où le contact est validé (`ContactResolver.plan_contact`).
	return {"kind": ContactResolver.serve_kind(actor, p, _feet(body, gp, t_commit)), "contact_at": elapsed + t_commit}


static func _feet(body: PlayerBody, gp: float, t: float) -> float:
	return 0.0 if body.grounded else maxf(0.0, body.position.y + body.velocity.y * t - 0.5 * gp * t * t)
