class_name PlayerActor
extends RefCounted
## Un joueur dans la simulation : corps physique + machine d'actions (Phase 0, section F) + contacts.
## Un appui engage l'action ; le contact n'a lieu que si le ballon traverse la zone pendant la
## fenêtre active. L'acteur ne marque aucun point : il signale ses contacts dans `ctx.contacts`.

const WINDOW_STATES := [Enums.ActionState.RECEIVE, Enums.ActionState.SET, Enums.ActionState.SPIKE,
	Enums.ActionState.FEINT, Enums.ActionState.SERVE_HIT]

var slot := 0
var team := 0
var character: CharacterDefinition
var body := PlayerBody.new()
var facing := 1
var state: int = Enums.ActionState.FREE
var state_time := 0.0

var _kind: StringName = &""
var _recover_len := 0.0
var _air_used := false
var _block_used := false
var _jump_v0 := 1.0
var _locked := false
var _auto_x := 0.0
var _serving := false
var _axis := 0.0
var _best_distance := INF


func _init(player_slot: int, team_index: int, definition: CharacterDefinition, start_x: float, look_dir: int) -> void:
	slot = player_slot
	team = team_index
	character = definition
	facing = look_dir
	body.position = Vector2(start_x, 0.0)


# ------------------------------------------------------------------ ordres de l'arbitre (MatchSim)
## Immobilise le joueur : il rejoint `x` automatiquement et ignore ses entrées.
func lock_to(x: float) -> void:
	_locked = true
	_serving = false
	_auto_x = x


func unlock() -> void:
	_locked = false


## Remet le joueur au sol en `x`, sans action en cours.
func reset_to(x: float) -> void:
	body.position = Vector2(x, 0.0)
	body.velocity = Vector2.ZERO
	body.grounded = true
	_serving = false
	_enter(Enums.ActionState.FREE)


func begin_serve() -> void:
	_locked = false
	_serving = true
	_enter(Enums.ActionState.SERVE_HOLD)


## Position de la main qui tient le ballon avant le lancer.
func serve_hold_position(p: ParamStore) -> Vector2:
	return body.position + Vector2(facing * p.get_value(ParamIds.SERVE_ZONE_DX), p.get_value(ParamIds.SERVE_ZONE_DY) * 0.5)


# ------------------------------------------------------------------ un tick
## `ball_from` = position du ballon au début du tick (le ballon a déjà été avancé).
func tick(intent: PlayerIntent, ctx: SimContext, ball_from: Vector2) -> void:
	var p := ctx.params
	state_time += ctx.dt
	if _locked:
		intent = PlayerIntent.make()
	_axis = intent.move_axis
	_handle_input(intent, ctx)
	var landed := _move(intent, ctx)
	if landed:
		ctx.emit(MatchEvent.Type.PLAYER_LANDED, {"slot": slot})
		_serving = false
		_enter(Enums.ActionState.RECOVER, p.get_value(ParamIds.LAND_RECOVER_S))
	if WINDOW_STATES.has(state):
		_update_window(ctx, ball_from)
	elif state == Enums.ActionState.BLOCK_AIR and not _block_used and not ctx.ball_held:
		if BlockResolver.try_block(self, ctx, ball_from, _jump_v0):
			_block_used = true
			ctx.contacts.append({"slot": slot, "kind": "block", "block": true})
	elif state == Enums.ActionState.RECOVER and state_time >= _recover_len:
		_enter(Enums.ActionState.FREE if body.grounded else Enums.ActionState.AIR)
	if _locked and body.grounded and state == Enums.ActionState.FREE:
		_enter(Enums.ActionState.LOCKED)
	elif not _locked and state == Enums.ActionState.LOCKED:
		_enter(Enums.ActionState.FREE)


func snapshot(p: ParamStore) -> PlayerSnapshot:
	var s := PlayerSnapshot.new()
	s.slot = slot
	s.team = team
	s.role = character.role
	s.character_id = character.id
	s.position = body.position
	s.velocity = body.velocity
	s.facing = facing
	s.grounded = body.grounded
	s.action = state
	s.action_time = state_time
	var receive := ContactSpec.of(ContactSpec.RECEIVE, p)
	var spike := ContactSpec.of(ContactSpec.SPIKE, p)
	s.receive_center = receive.center(body.position, facing)
	s.receive_radius = receive.radius
	s.spike_center = spike.center(body.position, facing)
	s.spike_radius = spike.radius
	if WINDOW_STATES.has(state):
		var spec := ContactSpec.of(_kind, p)
		if state_time >= spec.t_on and state_time <= spec.t_off:
			s.active_kind = String(_kind)
			s.active_center = spec.center(body.position, facing)
			s.active_radius = spec.radius
	elif state == Enums.ActionState.BLOCK_AIR:
		s.active_kind = "block"
		s.active_center = body.position + Vector2(facing * p.get_value(ParamIds.BLOCK_ZONE_DX), p.get_value(ParamIds.BLOCK_ZONE_DY))
		s.active_radius = p.get_value(ParamIds.BLOCK_ZONE_RADIUS)
	return s


# ------------------------------------------------------------------ entrées et transitions
func _handle_input(intent: PlayerIntent, ctx: SimContext) -> void:
	var press := intent.first_press()
	match state:
		Enums.ActionState.FREE:
			if press == &"jump":
				_do_jump(ctx, Enums.ActionState.AIR)
			elif press == &"set":
				_begin_window(ctx, ContactSpec.SET, Enums.ActionState.SET)
			elif press == &"receive":
				if _near_net(ctx) and _ball_at_opponent(ctx):
					_enter(Enums.ActionState.BLOCK_READY)
				else:
					_begin_window(ctx, ContactSpec.RECEIVE, Enums.ActionState.RECEIVE)
		Enums.ActionState.BLOCK_READY:
			if not intent.receive_held:
				_enter(Enums.ActionState.FREE)
			elif intent.jump_pressed:
				_do_jump(ctx, Enums.ActionState.BLOCK_AIR)
		Enums.ActionState.AIR:
			if _air_used or body.grounded:
				return
			if press == &"jump":
				_begin_window(ctx, ContactSpec.SPIKE, Enums.ActionState.SPIKE)
			elif press == &"set":
				_begin_window(ctx, ContactSpec.SET, Enums.ActionState.SET)
			elif press == &"receive":
				_begin_window(ctx, ContactSpec.FEINT, Enums.ActionState.FEINT)
		Enums.ActionState.SERVE_HOLD:
			if intent.serve_pressed:
				ctx.ball_held = false
				ctx.ball.position = serve_hold_position(ctx.params)
				ctx.ball.velocity = Vector2(0.0, ctx.params.get_value(ParamIds.SERVE_TOSS_SPEED))
				ctx.emit(MatchEvent.Type.SERVE_TOSSED, {"slot": slot})
				_enter(Enums.ActionState.SERVE_TOSS)
		Enums.ActionState.SERVE_TOSS:
			if intent.serve_pressed:
				_begin_window(ctx, ContactSpec.SERVE, Enums.ActionState.SERVE_HIT)
			elif intent.jump_pressed:
				_do_jump(ctx, Enums.ActionState.SERVE_JUMP)
		Enums.ActionState.SERVE_JUMP:
			if intent.serve_pressed:
				_begin_window(ctx, ContactSpec.SERVE, Enums.ActionState.SERVE_HIT)


func _do_jump(ctx: SimContext, new_state: int) -> void:
	var p := ctx.params
	var apex := StatConversion.jump_apex(character.stats, p)
	_jump_v0 = sqrt(2.0 * p.get_value(ParamIds.PLAYER_GRAVITY) * apex)
	body.jump(_jump_v0)
	_air_used = false
	_block_used = false
	_enter(new_state)
	ctx.emit(MatchEvent.Type.PLAYER_JUMPED, {"slot": slot})


func _begin_window(ctx: SimContext, kind: StringName, new_state: int) -> void:
	_kind = kind
	_best_distance = INF
	_enter(new_state)
	ctx.emit(MatchEvent.Type.ACTION_STARTED, {"slot": slot, "action": String(kind)})


func _enter(new_state: int, recover_len := 0.0) -> void:
	state = new_state
	state_time = 0.0
	_recover_len = recover_len


func _near_net(ctx: SimContext) -> bool:
	return absf(body.position.x) < ctx.params.get_value(ParamIds.NET_ZONE)


## « Ballon chez l'adversaire » : dans son camp, ou dernier toucheur adverse.
func _ball_at_opponent(ctx: SimContext) -> bool:
	return ctx.ball.position.x * facing > 0.0 or (ctx.rally.last_team >= 0 and ctx.rally.last_team != team)


# ------------------------------------------------------------------ mouvement
## Renvoie true si le joueur vient de toucher le sol.
func _move(intent: PlayerIntent, ctx: SimContext) -> bool:
	var p := ctx.params
	var max_speed := StatConversion.run_speed(character.stats, p)
	var axis := intent.move_axis
	var air_grip: float = p.get_value(ParamIds.AIR_CONTROL)
	match state:
		Enums.ActionState.LOCKED:
			var gap := _auto_x - body.position.x
			if absf(gap) <= max_speed * ctx.dt:
				body.position.x = _auto_x
				body.velocity.x = 0.0
				axis = 0.0
			else:
				axis = signf(gap)
		Enums.ActionState.RECEIVE, Enums.ActionState.SET, Enums.ActionState.SPIKE, Enums.ActionState.FEINT, \
		Enums.ActionState.SERVE_HIT, Enums.ActionState.RECOVER:
			max_speed *= p.get_value(ParamIds.ACTION_MOVE_FACTOR)
		Enums.ActionState.BLOCK_READY:
			max_speed *= p.get_value(ParamIds.BLOCK_READY_MOVE_MULT)
		Enums.ActionState.BLOCK_AIR:
			air_grip *= p.get_value(ParamIds.BLOCK_AIR_CONTROL_MULT)
		Enums.ActionState.SERVE_TOSS:
			max_speed = 0.0
	var near := ctx.court.net_half_thickness + p.get_value(ParamIds.PLAYER_HALF_WIDTH)
	var far := ctx.court.half_length + ctx.court.out_margin
	var x_min := -far if facing > 0 else near
	var x_max := -near if facing > 0 else far
	if _serving:   # le service se fait derrière la ligne de fond
		var line := -facing * ctx.court.half_length
		var back := -facing * (ctx.court.half_length + p.get_value(ParamIds.SERVE_LINE_DEPTH))
		x_min = minf(line, back)
		x_max = maxf(line, back)
	return body.step(ctx.dt, axis, max_speed, p.get_value(ParamIds.GROUND_ACCEL), p.get_value(ParamIds.GROUND_DECEL),
		air_grip, p.get_value(ParamIds.PLAYER_GRAVITY), x_min, x_max)


# ------------------------------------------------------------------ fenêtres de contact
## Le contact est validé au point d'approche maximale du ballon dans la zone : la distance au centre
## mesurée à ce moment donne l'erreur de position (un ballon qui ne fait qu'effleurer le bord de la
## zone donne une mauvaise qualité, un ballon qui passe au centre une bonne).
func _update_window(ctx: SimContext, ball_from: Vector2) -> void:
	var spec := ContactSpec.of(_kind, ctx.params)
	if state_time > spec.t_off:
		if _best_distance < INF:
			_commit(ctx, spec, _best_distance)   # la fenêtre se ferme avec le ballon dans la zone
		else:
			_end_action(ctx, true)
		return
	if state_time < spec.t_on or ctx.ball_held:
		return
	var center := spec.center(body.position, facing)
	var distance := SweptCollision.point_segment_distance(center, ball_from, ctx.ball.position)
	if distance <= spec.radius:
		_best_distance = minf(_best_distance, distance)
		if SweptCollision.closest_fraction(center, ball_from, ctx.ball.position) < 1.0:
			_commit(ctx, spec, distance)   # l'approche maximale a eu lieu pendant ce tick
	elif _best_distance < INF:
		_commit(ctx, spec, _best_distance)   # le ballon est ressorti de la zone


func _commit(ctx: SimContext, spec: ContactSpec, distance: float) -> void:
	var details := ContactResolver.resolve(spec, self, ctx, state_time, distance, _axis * facing)
	ctx.emit(MatchEvent.Type.CONTACT, details)
	ctx.contacts.append({"slot": slot, "kind": String(_kind), "block": false})
	_end_action(ctx, false)


## Fin de fenêtre (touchée ou ratée) : sol → récupération ; air → retour à l'état aérien.
func _end_action(ctx: SimContext, missed: bool) -> void:
	if missed:
		ctx.emit(MatchEvent.Type.ACTION_MISSED, {"slot": slot, "action": String(_kind)})
	if state == Enums.ActionState.SERVE_HIT:
		_serving = false
	if body.grounded:
		_enter(Enums.ActionState.RECOVER, ctx.params.get_value(ParamIds.RECOVER_S))
	else:
		_air_used = true
		_enter(Enums.ActionState.AIR)
