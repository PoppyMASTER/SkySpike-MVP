class_name BlockResolver
extends RefCounted
## Contre : attaque contre bloc, jamais binaire. Chaque terme est publié dans BLOCK_RESOLVED.
##   écart = qualité de bloc − qualité d'attaque + biais (+ bruit)
##   > seuil_contre : contre gagnant ; entre les deux seuils : bloc partiel ; sinon : le ballon passe.


## Renvoie true si le ballon a été touché par les mains de `actor` pendant ce tick.
static func try_block(actor: PlayerActor, ctx: SimContext, ball_from: Vector2, v0: float) -> bool:
	var p := ctx.params
	var ball := ctx.ball
	if ball.velocity.x * actor.facing >= 0.0:
		return false   # le ballon ne vient pas de l'adversaire
	var center := actor.body.position + Vector2(actor.facing * p.get_value(ParamIds.BLOCK_ZONE_DX), p.get_value(ParamIds.BLOCK_ZONE_DY))
	var radius: float = p.get_value(ParamIds.BLOCK_ZONE_RADIUS)
	var distance := SweptCollision.point_segment_distance(center, ball_from, ball.position)
	if distance > radius:
		return false
	var velocity := ball.velocity
	var speed := velocity.length()
	var attack: float = p.get_value(ParamIds.BLOCK_ATTACK_W_SPEED) * clampf(speed / p.get_value(ParamIds.BLOCK_REF_SPEED), 0.0, 1.5) \
		+ p.get_value(ParamIds.BLOCK_ATTACK_W_QUALITY) * ctx.rally.last_quality
	var timing := 1.0 - clampf(absf(actor.body.velocity.y) / maxf(v0, 1e-3), 0.0, 1.0)
	var align := 1.0 - clampf(distance / radius, 0.0, 1.0)
	var margin := clampf(0.5 + 0.5 * (center.y - ball.position.y) / maxf(p.get_value(ParamIds.BLOCK_HAND_EXTRA), 1e-3), 0.0, 1.0)
	var w_t: float = p.get_value(ParamIds.BLOCK_W_TIMING)
	var w_a: float = p.get_value(ParamIds.BLOCK_W_ALIGN)
	var w_m: float = p.get_value(ParamIds.BLOCK_W_MARGIN)
	var w_sum := maxf(w_t + w_a + w_m, 1e-6)
	var block_q := StatConversion.block_factor(actor.character.stats, p) * (w_t * timing + w_a * align + w_m * margin) / w_sum
	var noise := 0.0
	var sigma: float = p.get_value(ParamIds.BLOCK_NOISE)
	if sigma > 0.0:
		noise = ctx.rng.gaussian_tagged(MatchRng.STREAM_CONTACTS, "block_gap", sigma)
	var gap := block_q - attack + p.get_value(ParamIds.BLOCK_BIAS) + noise
	var outcome := "pass"
	if gap > p.get_value(ParamIds.BLOCK_STUFF_THRESHOLD):
		outcome = "stuff"
		var down := -maxf(absf(velocity.y), absf(velocity.x))
		ball.velocity = Vector2(-velocity.x, down).normalized() * p.get_value(ParamIds.BLOCK_STUFF_SPEED)
	elif gap > p.get_value(ParamIds.BLOCK_TOUCH_THRESHOLD):
		outcome = "touch"
		ball.velocity = velocity * p.get_value(ParamIds.BLOCK_TOUCH_DAMP) + Vector2(0.0, p.get_value(ParamIds.BLOCK_TOUCH_LIFT))
	else:
		ball.velocity = velocity.rotated(p.get_value(ParamIds.BLOCK_PASS_DEFLECT) * signf(velocity.x))
	ctx.emit(MatchEvent.Type.BLOCK_RESOLVED, {
		"slot": actor.slot, "outcome": outcome, "attack": snappedf(attack, 0.001), "block": snappedf(block_q, 0.001),
		"timing": snappedf(timing, 0.001), "align": snappedf(align, 0.001), "margin": snappedf(margin, 0.001),
		"gap": snappedf(gap, 0.001)})
	return true
