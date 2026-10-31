class_name ContactResolver
extends RefCounted
## Qualité et vitesse de sortie d'un contact, y compris la correction de visée (assistée ou IA).
## Tous les termes partent dans l'événement CONTACT.

const BASE_ANGLE := {
	ContactSpec.RECEIVE: ParamIds.RECEIVE_ANGLE, ContactSpec.SET: ParamIds.SET_ANGLE,
	ContactSpec.SPIKE: ParamIds.SPIKE_ANGLE, ContactSpec.FEINT: ParamIds.FEINT_ANGLE,
	ContactSpec.SERVE: ParamIds.SERVE_ANGLE,
}


## Applique le contact : met à jour la vitesse du ballon et renvoie les détails de l'événement.
static func resolve(spec: ContactSpec, actor: PlayerActor, ctx: SimContext, elapsed: float, distance: float, aim: float) -> Dictionary:
	var p := ctx.params
	var tolerance := spec.tolerance
	if ctx.is_human(actor.slot) and _assisted(p):
		tolerance *= p.get_value(ParamIds.ASSIST_TOLERANCE_MULT)
	var e_t := ContactModel.time_error(elapsed, spec.ideal, tolerance)
	var e_s := ContactModel.space_error(distance, spec.radius)
	var q := ContactModel.quality(e_t, e_s, p.get_value(ParamIds.CONTACT_W_TIME), p.get_value(ParamIds.CONTACT_W_SPACE))
	var speed := ContactModel.speed(_top_speed(spec.kind, actor, p), q, p.get_value(ParamIds.QUALITY_SPEED_FLOOR))
	var noise := ctx.rng.gaussian_tagged(MatchRng.STREAM_CONTACTS, "%s_angle" % spec.kind, _noise(spec.kind, actor, p))
	var shift: float = p.get_value(ParamIds.TIMING_ANGLE_SHIFT)
	var base: float = p.get_value(BASE_ANGLE[spec.kind])
	var max_correction := _max_correction(ctx, actor.slot, p)
	var angle: float
	var correction := 0.0
	if max_correction > 0.0:
		var natural := ContactModel.exit_angle(base, e_t, shift, 0.0, 0.0, 0.0)
		var solved := _solve_target_angle(spec.kind, actor, ctx, speed, aim)
		if not is_nan(solved):
			solved = maxf(solved, _net_clearing_angle(actor, ctx, speed))
			correction = clampf(solved - natural, -max_correction, max_correction)
		angle = clampf(natural + correction + noise, -ContactModel.ANGLE_LIMIT, ContactModel.ANGLE_LIMIT)
	else:
		angle = ContactModel.exit_angle(base, e_t, shift, aim, p.get_value(ParamIds.AIM_RANGE), noise)
	ctx.ball.velocity = ContactModel.exit_velocity(speed, angle, actor.facing)
	ctx.rally.last_quality = q
	return {
		"slot": actor.slot, "action": String(spec.kind),
		"q": snappedf(q, 0.001), "e_t": snappedf(e_t, 0.001), "e_s": snappedf(e_s, 0.001),
		"assist": snappedf(correction, 0.0001), "speed": snappedf(speed, 0.001), "angle": snappedf(angle, 0.0001),
	}


static func _assisted(p: ParamStore) -> bool:
	return int(p.get_value(ParamIds.AIM_MODE)) == 1


## Plafond de correction d'angle : 0 = visée manuelle (humain en mode manuel).
static func _max_correction(ctx: SimContext, slot: int, p: ParamStore) -> float:
	if not ctx.is_human(slot):
		return p.get_value(ParamIds.AI_ASSIST_MAX_ANGLE)
	return p.get_value(ParamIds.ASSIST_MAX_ANGLE) if _assisted(p) else 0.0


static func _top_speed(kind: StringName, actor: PlayerActor, p: ParamStore) -> float:
	var stats := actor.character.stats
	match kind:
		ContactSpec.RECEIVE:
			return p.get_value(ParamIds.RECEIVE_SPEED)
		ContactSpec.SET:
			return StatConversion.set_speed_max(stats, p)
		ContactSpec.FEINT:
			return p.get_value(ParamIds.FEINT_SPEED)
		ContactSpec.SERVE:
			return StatConversion.serve_speed(stats, p)
	return StatConversion.spike_speed(stats, p)


static func _noise(kind: StringName, actor: PlayerActor, p: ParamStore) -> float:
	var stats := actor.character.stats
	match kind:
		ContactSpec.RECEIVE:
			return StatConversion.receive_angle_noise(stats, p)
		ContactSpec.SET:
			return StatConversion.set_angle_noise(stats, p)
	return StatConversion.spike_angle_noise(stats, p)


## Angle qui enverrait le ballon vers la cible de l'action (NAN si aucune cible ou hors de portée).
static func _solve_target_angle(kind: StringName, actor: PlayerActor, ctx: SimContext, speed: float, aim: float) -> float:
	var p := ctx.params
	var from := ctx.ball.position
	var target := Vector2.ZERO
	var high := false
	match kind:
		ContactSpec.RECEIVE:
			var setter := ctx.teammate_by_role(actor.slot, Enums.Role.SETTER)
			if setter == null:
				return NAN
			target = Vector2(setter.body.position.x, p.get_value(ParamIds.ASSIST_RECEIVE_TARGET_Y))
			high = true
		ContactSpec.SET:
			var hitter := ctx.teammate_by_role(actor.slot, Enums.Role.ATTACKER)
			if hitter == null:
				return NAN
			target = Vector2(hitter.body.position.x, p.get_value(ParamIds.ASSIST_SET_TARGET_Y))
			high = true
		ContactSpec.FEINT:
			target = Vector2(actor.facing * p.get_value(ParamIds.ASSIST_FEINT_DROP_X), ctx.ball.radius)
		_:   # SPIKE, SERVE : un point du camp adverse, plus ou moins profond selon la direction tenue
			var lo: float = p.get_value(ParamIds.ASSIST_RATIO_MIN)
			var hi: float = p.get_value(ParamIds.ASSIST_RATIO_MAX)
			var depth := lerpf(lo, hi, 0.5 + 0.5 * clampf(aim, -1.0, 1.0))
			target = Vector2(actor.facing * ctx.court.half_length * depth, ctx.ball.radius)
			high = false
	return Ballistics.angle_to_pass(from, speed, target, p.get_value(ParamIds.BALL_GRAVITY), high)


## Angle minimal pour passer au-dessus du filet (avec la marge de l'assistance). -INF si le tir
## ne part pas de son camp ou n'a pas besoin d'être relevé.
static func _net_clearing_angle(actor: PlayerActor, ctx: SimContext, speed: float) -> float:
	var from := ctx.ball.position
	if from.x * actor.facing >= 0.0:
		return -INF
	var p := ctx.params
	var top := ctx.court.net_height + ctx.ball.radius + p.get_value(ParamIds.ASSIST_NET_CLEARANCE)
	var angle := Ballistics.angle_to_pass(from, speed, Vector2(0.0, top), p.get_value(ParamIds.BALL_GRAVITY), false)
	return -INF if is_nan(angle) else angle
