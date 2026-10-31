class_name AiServe
extends RefCounted
## Le service de l'IA, avec les mêmes commandes qu'un humain : maintient L pour charger le lancer,
## relâche, saute au bon moment sous le ballon, frappe en l'air. Elle lit son propre lancer
## (pas de délai ni d'erreur de perception) ; ses tirages (charge, profondeur) viennent du flux `ai`.

var _params: ParamStore
var _rng: MatchRng
var _dt: float
var _planned := false
var _hold_time := 0.0
var _held_for := 0.0
var _aim := 0.0


func _init(params: ParamStore, rng: MatchRng, tick_seconds: float) -> void:
	_params = params
	_rng = rng
	_dt = tick_seconds


## Vrai si ce joueur est en train de servir (c'est AiServe qui décide de ses commandes).
func handles(slot: int, now: MatchState) -> bool:
	if slot != now.server_slot or now.served:
		return false
	var action := now.players[slot].action
	return action == Enums.ActionState.SERVE_HOLD or action == Enums.ActionState.SERVE_TOSS \
		or action == Enums.ActionState.SERVE_JUMP or action == Enums.ActionState.SERVE_HIT


## `apex` = hauteur du saut du joueur, `timing_error` = erreur de timing tirée pour ce coup.
func decide(slot: int, now: MatchState, apex: float, timing_error: float) -> PlayerIntent:
	var me := now.players[slot]
	match me.action:
		Enums.ActionState.SERVE_HOLD:
			return _hold(now)
		Enums.ActionState.SERVE_TOSS:
			return _toss(me, now, apex)
		Enums.ActionState.SERVE_JUMP:
			return _strike(me, now, timing_error)
		Enums.ActionState.SERVE_HIT:   # la direction tenue pendant la frappe = profondeur visée
			return PlayerIntent.make(_aim)
	return PlayerIntent.make()


func _hold(now: MatchState) -> PlayerIntent:
	if now.phase_time < _params.get_value(ParamIds.AI_SERVE_DELAY):
		return PlayerIntent.make()
	var charge_time: float = _params.get_value(ParamIds.SERVE_CHARGE_TIME)
	if not _planned:
		var wanted := clampf(_params.get_value(ParamIds.AI_SERVE_CHARGE) + _rng.gaussian_tagged(MatchRng.STREAM_AI, "serve_charge", _params.get_value(ParamIds.AI_SERVE_CHARGE_SPREAD)), 0.0, 1.0)
		_aim = clampf(_rng.gaussian_tagged(MatchRng.STREAM_AI, "serve_aim", _params.get_value(ParamIds.AI_SERVE_AIM_SPREAD)), -1.0, 1.0)
		_hold_time = wanted * charge_time
		_held_for = 0.0
		_planned = true
		return PlayerIntent.make(0.0, false, false, false, false, true, true)   # appui : la charge commence
	_held_for += _dt
	if _held_for < _hold_time:
		return PlayerIntent.make(0.0, false, false, false, false, false, true)
	_planned = false
	return PlayerIntent.make()   # relâché : le ballon part


## Ballon en l'air : se placer sous lui et sauter pour que le sommet du saut tombe à sa rencontre.
func _toss(me: PlayerSnapshot, now: MatchState, apex: float) -> PlayerIntent:
	var spec := ContactSpec.of(ContactSpec.SERVE, _params)
	var g: float = _params.get_value(ParamIds.BALL_GRAVITY)
	var gp: float = _params.get_value(ParamIds.PLAYER_GRAVITY)
	var reach := spec.dy + apex
	var t_meet := Ballistics.time_to_height(now.ball_position.y, now.ball_velocity.y, g, reach)
	if t_meet < 0.0:
		t_meet = maxf(0.0, now.ball_velocity.y / g)   # ballon trop bas pour la zone au sommet : on vise son sommet
	var meet_x := now.ball_position.x + now.ball_velocity.x * t_meet
	var jump_in := t_meet - sqrt(2.0 * apex / gp)   # le sommet du saut dure sqrt(2·apex/g)
	var axis := 0.0
	var gap := meet_x - me.facing * spec.dx - me.position.x
	if absf(gap) > _params.get_value(ParamIds.AI_POSITION_TOL):
		axis = clampf(gap / 0.4, -1.0, 1.0)
	return PlayerIntent.make(axis, jump_in <= _dt)


## En l'air : frapper quand le ballon sera le plus près de la zone, un « instant idéal » plus tard.
func _strike(me: PlayerSnapshot, now: MatchState, timing_error: float) -> PlayerIntent:
	var spec := ContactSpec.of(ContactSpec.SERVE, _params)
	var g: float = _params.get_value(ParamIds.BALL_GRAVITY)
	var gp: float = _params.get_value(ParamIds.PLAYER_GRAVITY)
	var best_t := 0.0
	var best_d := INF
	var step := _dt * 2.0
	var t := 0.0
	while t <= 1.2:
		var ball := Ballistics.position_at(now.ball_position, now.ball_velocity, g, t)
		var y := maxf(0.0, me.position.y + me.velocity.y * t - 0.5 * gp * t * t)
		var d := ball.distance_to(spec.center(Vector2(me.position.x, y), me.facing))
		if d < best_d:
			best_d = d
			best_t = t
		t += step
	var press := best_t - (spec.ideal + timing_error) <= 0.0
	return PlayerIntent.make(0.0, false, false, false, false, press, press)
