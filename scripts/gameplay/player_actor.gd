class_name PlayerActor
extends RefCounted
## Un joueur dans la simulation : corps physique + machine d'actions + contacts avec le ballon.
## J2 : FREE, RECEIVE, AIR, SPIKE, RECOVER. Un appui engage l'action ; le contact n'a lieu que si
## le ballon traverse la zone pendant la fenêtre active.

var slot := 0
var character: CharacterDefinition
var body := PlayerBody.new()
var facing := 1
var state: int = Enums.ActionState.FREE
var state_time := 0.0

var _recover_len := 0.0
var _spike_used := false
var _axis := 0.0
var _active_zone: int = PlayerSnapshot.Zone.NONE


func _init(player_slot: int, definition: CharacterDefinition, start_x: float, look_dir: int) -> void:
	slot = player_slot
	character = definition
	facing = look_dir
	body.position = Vector2(start_x, 0.0)


## Un tick. `ball_from` = position du ballon au début du tick (le ballon a déjà été avancé).
func tick(intent: PlayerIntent, ctx: SimContext, ball_from: Vector2) -> void:
	var p := ctx.params
	state_time += ctx.dt
	_axis = intent.move_axis
	_start_actions(intent, ctx)
	var in_action := state == Enums.ActionState.RECEIVE or state == Enums.ActionState.SPIKE
	var max_speed := StatConversion.run_speed(character.stats, p)
	if in_action:
		max_speed *= p.get_value(ParamIds.ACTION_MOVE_FACTOR)
	var near := ctx.court.net_half_thickness + p.get_value(ParamIds.PLAYER_HALF_WIDTH)
	var far := ctx.court.half_length + ctx.court.out_margin
	var x_min := -far if facing > 0 else near
	var x_max := -near if facing > 0 else far
	var landed := body.step(ctx.dt, intent.move_axis, max_speed, p.get_value(ParamIds.GROUND_ACCEL),
		p.get_value(ParamIds.GROUND_DECEL), p.get_value(ParamIds.AIR_CONTROL),
		p.get_value(ParamIds.PLAYER_GRAVITY), x_min, x_max)
	if landed:
		ctx.emit(MatchEvent.Type.PLAYER_LANDED, {"slot": slot})
		if state == Enums.ActionState.AIR or state == Enums.ActionState.SPIKE:
			_enter(Enums.ActionState.RECOVER, p.get_value(ParamIds.LAND_RECOVER_S))
	if state == Enums.ActionState.RECEIVE or state == Enums.ActionState.SPIKE:
		_update_window(ctx, ball_from)
	elif state == Enums.ActionState.RECOVER and state_time >= _recover_len:
		_enter(Enums.ActionState.FREE if body.grounded else Enums.ActionState.AIR)


func snapshot(p: ParamStore) -> PlayerSnapshot:
	var s := PlayerSnapshot.new()
	s.character_id = character.id
	s.position = body.position
	s.velocity = body.velocity
	s.facing = facing
	s.grounded = body.grounded
	s.action = state
	s.action_time = state_time
	s.receive_center = _zone_center(ParamIds.RECEIVE_ZONE_DX, ParamIds.RECEIVE_ZONE_DY, p)
	s.receive_radius = p.get_value(ParamIds.RECEIVE_ZONE_RADIUS)
	s.spike_center = _zone_center(ParamIds.SPIKE_ZONE_DX, ParamIds.SPIKE_ZONE_DY, p)
	s.spike_radius = p.get_value(ParamIds.SPIKE_ZONE_RADIUS)
	s.active_zone = _active_zone
	return s


func _start_actions(intent: PlayerIntent, ctx: SimContext) -> void:
	var p := ctx.params
	if state == Enums.ActionState.FREE and body.grounded:
		if intent.jump_pressed:
			var apex := StatConversion.jump_apex(character.stats, p)
			body.jump(sqrt(2.0 * p.get_value(ParamIds.PLAYER_GRAVITY) * apex))
			_spike_used = false
			_enter(Enums.ActionState.AIR)
			ctx.emit(MatchEvent.Type.PLAYER_JUMPED, {"slot": slot})
		elif intent.receive_pressed:
			_enter(Enums.ActionState.RECEIVE)
			ctx.emit(MatchEvent.Type.ACTION_STARTED, {"slot": slot, "action": "receive"})
	elif state == Enums.ActionState.AIR and not body.grounded and intent.jump_pressed and not _spike_used:
		_spike_used = true
		_enter(Enums.ActionState.SPIKE)
		ctx.emit(MatchEvent.Type.ACTION_STARTED, {"slot": slot, "action": "spike"})


func _enter(new_state: int, recover_len := 0.0) -> void:
	state = new_state
	state_time = 0.0
	_recover_len = recover_len
	_active_zone = PlayerSnapshot.Zone.NONE


func _update_window(ctx: SimContext, ball_from: Vector2) -> void:
	var p := ctx.params
	var is_receive := state == Enums.ActionState.RECEIVE
	var t_on: float = p.get_value(ParamIds.RECEIVE_ON if is_receive else ParamIds.SPIKE_ON)
	var t_off: float = p.get_value(ParamIds.RECEIVE_OFF if is_receive else ParamIds.SPIKE_OFF)
	if state_time > t_off:
		_end_action(ctx, true)
		return
	if state_time < t_on:
		return
	_active_zone = PlayerSnapshot.Zone.RECEIVE if is_receive else PlayerSnapshot.Zone.SPIKE
	var center := _zone_center(ParamIds.RECEIVE_ZONE_DX if is_receive else ParamIds.SPIKE_ZONE_DX,
		ParamIds.RECEIVE_ZONE_DY if is_receive else ParamIds.SPIKE_ZONE_DY, p)
	var radius: float = p.get_value(ParamIds.RECEIVE_ZONE_RADIUS if is_receive else ParamIds.SPIKE_ZONE_RADIUS)
	var distance := SweptCollision.point_segment_distance(center, ball_from, ctx.ball.position)
	if distance <= radius:
		_contact(ctx, is_receive, distance, radius)
		_end_action(ctx, false)


func _contact(ctx: SimContext, is_receive: bool, distance: float, radius: float) -> void:
	var p := ctx.params
	var ideal: float = p.get_value(ParamIds.RECEIVE_IDEAL if is_receive else ParamIds.SPIKE_IDEAL)
	var tolerance: float = p.get_value(ParamIds.RECEIVE_TIME_TOL if is_receive else ParamIds.SPIKE_TIME_TOL)
	var e_t := ContactModel.time_error(state_time, ideal, tolerance)
	var e_s := ContactModel.space_error(distance, radius)
	var q := ContactModel.quality(e_t, e_s, p.get_value(ParamIds.CONTACT_W_TIME), p.get_value(ParamIds.CONTACT_W_SPACE))
	var top_speed: float = p.get_value(ParamIds.RECEIVE_SPEED) if is_receive else StatConversion.spike_speed(character.stats, p)
	var sigma: float = StatConversion.receive_angle_noise(character.stats, p) if is_receive \
		else StatConversion.spike_angle_noise(character.stats, p)
	var action_name := "receive" if is_receive else "spike"
	var noise := ctx.rng.gaussian_tagged(MatchRng.STREAM_CONTACTS, "%s_angle" % action_name, sigma)
	var speed_value := ContactModel.speed(top_speed, q, p.get_value(ParamIds.QUALITY_SPEED_FLOOR))
	var angle := ContactModel.exit_angle(p.get_value(ParamIds.RECEIVE_ANGLE if is_receive else ParamIds.SPIKE_ANGLE),
		e_t, p.get_value(ParamIds.TIMING_ANGLE_SHIFT), _axis * facing, p.get_value(ParamIds.AIM_RANGE), noise)
	ctx.ball.velocity = ContactModel.exit_velocity(speed_value, angle, facing)
	ctx.emit(MatchEvent.Type.CONTACT, {
		"slot": slot, "action": action_name,
		"q": snappedf(q, 0.001), "e_t": snappedf(e_t, 0.001), "e_s": snappedf(e_s, 0.001),
		"speed": snappedf(speed_value, 0.001), "angle": snappedf(angle, 0.0001),
	})


## Fin de fenêtre (touchée ou ratée) : retour au sol avec récupération, ou en l'air sans second smash.
func _end_action(ctx: SimContext, missed: bool) -> void:
	if missed:
		ctx.emit(MatchEvent.Type.ACTION_MISSED, {
			"slot": slot, "action": "receive" if state == Enums.ActionState.RECEIVE else "spike"})
	if body.grounded:
		_enter(Enums.ActionState.RECOVER, ctx.params.get_value(ParamIds.RECOVER_S))
	else:
		_enter(Enums.ActionState.AIR)


func _zone_center(dx_id: StringName, dy_id: StringName, p: ParamStore) -> Vector2:
	return body.position + Vector2(facing * p.get_value(dx_id), p.get_value(dy_id))
