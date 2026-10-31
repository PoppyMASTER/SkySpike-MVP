class_name AiDirector
extends RefCounted
## IA de base des joueurs non pilotés. Elle produit des PlayerIntent comme le clavier : mêmes touches,
## mêmes fenêtres de timing, même résolution de contact. Elle ne lit que MatchState, avec un temps
## de réaction (état d'il y a `ai_reaction_s`) et une erreur de prédiction tirée dans le flux « ai ».
##
## Rôles du rallye : 1re touche = réception, 2e = passe (passeur), 3e = smash ou feinte (attaquant).
## Un attaquant peut tenter un contre quand l'adversaire a fait sa passe.

var params: ParamStore
var dt: float
var human_slot := -1
var _rng: MatchRng
var _history: Array[MatchState] = []
var _epoch := -1
var _pred_error: Array[float] = []
var _timing_error: Array[float] = []
var _feint: Array[bool] = []
var _block: Array[bool] = []
var _stats_apex: Array[float] = []
var _serve_aim: Dictionary = {}   # slot -> direction tenue à la frappe du service (tirée au lancer)


func _init(param_store: ParamStore, seed_value: int, tick_dt: float, human := -1) -> void:
	params = param_store
	dt = tick_dt
	human_slot = human
	_rng = MatchRng.new(seed_value)


## Une intention par slot (celle du slot humain est neutre : le clavier la remplace).
func intents(now: MatchState) -> Array[PlayerIntent]:
	_history.append(now)
	var lag_ticks := roundi(params.get_value(ParamIds.AI_REACTION_S) / dt)
	while _history.size() > lag_ticks + 2:
		_history.pop_front()
	var seen := _history[maxi(0, _history.size() - 1 - lag_ticks)]
	if now.contact_seq != _epoch or _pred_error.size() != now.players.size():
		_resample(now)
	var out: Array[PlayerIntent] = []
	for slot in now.players.size():
		out.append(PlayerIntent.make() if slot == human_slot else _decide(slot, now, seen))
	return out


## Nouveau coup joué : l'IA retire ses erreurs de prédiction et de timing et ses choix (6 tirages × 4).
func _resample(now: MatchState) -> void:
	_epoch = now.contact_seq
	_pred_error = []
	_timing_error = []
	_feint = []
	_block = []
	for slot in now.players.size():
		_pred_error.append(_rng.gaussian_tagged(MatchRng.STREAM_AI, "pred_error_%d" % slot, params.get_value(ParamIds.AI_PREDICTION_ERROR)))
		_timing_error.append(_rng.gaussian_tagged(MatchRng.STREAM_AI, "timing_error_%d" % slot, params.get_value(ParamIds.AI_TIMING_ERROR)))
		_feint.append(_rng.randf_tagged(MatchRng.STREAM_AI, "feint_%d" % slot) < params.get_value(ParamIds.AI_FEINT_CHANCE))
		_block.append(_rng.randf_tagged(MatchRng.STREAM_AI, "block_%d" % slot) < params.get_value(ParamIds.AI_BLOCK_CHANCE))


func _decide(slot: int, now: MatchState, seen: MatchState) -> PlayerIntent:
	var me := now.players[slot]
	if now.phase == Enums.Phase.SERVE_PREP:
		var wait: float = params.get_value(ParamIds.AI_SERVE_DELAY)
		if slot == now.server_slot and me.action == Enums.ActionState.SERVE_HOLD and now.phase_time >= wait:
			# comme un humain : la direction tenue au lancer donne la dérive du ballon (tirage unique par service)
			var toss := clampf(_rng.gaussian_tagged(MatchRng.STREAM_AI, "serve_toss_%d" % slot, params.get_value(ParamIds.AI_SERVE_TOSS_SPREAD)), -1.0, 1.0)
			_serve_aim[slot] = clampf(_rng.gaussian_tagged(MatchRng.STREAM_AI, "serve_aim_%d" % slot, params.get_value(ParamIds.AI_SERVE_AIM_SPREAD)), -1.0, 1.0)
			return PlayerIntent.make(toss, false, false, false, false, true)
		return PlayerIntent.make()
	if now.phase != Enums.Phase.BALL_LIVE:
		return PlayerIntent.make()
	if me.action == Enums.ActionState.SERVE_HIT:   # la direction tenue pendant la frappe = profondeur visée
		return PlayerIntent.make(_serve_aim.get(slot, 0.0))
	if me.action == Enums.ActionState.SERVE_TOSS:
		return _ground_action(slot, ContactSpec.SERVE, now, now, false, true)   # son propre lancer : ni délai ni erreur de perception
	var plan := _plan(me.team, now, seen)
	if plan.slot == slot:
		match plan.action:
			"set":
				return _ground_action(slot, ContactSpec.SET, now, seen, false)
			"attack":
				return _attack(slot, now, seen)
		return _ground_action(slot, ContactSpec.RECEIVE, now, seen, false)
	return _block_or_formation(slot, now, seen)


# ------------------------------------------------------------------ qui joue le ballon ?
## {slot, action} pour l'équipe `team` ; slot = -1 si personne n'a à jouer.
func _plan(team: int, now: MatchState, seen: MatchState) -> Dictionary:
	var facing := 1 if team == 0 else -1
	var ball := seen.ball_position
	var g: float = params.get_value(ParamIds.BALL_GRAVITY)
	var none := {"slot": -1, "action": ""}
	if ball.x * facing > 0.0 and now.last_team == team:
		return none   # le ballon est parti chez l'adversaire
	var n := 0
	if now.last_team == team:
		if now.touches[team] == 0 and not now.last_was_block:
			return none   # la balle vient d'être servie : elle part chez l'adversaire
		n = maxi(now.touches[team], 1)
	else:
		var t_land := Ballistics.time_to_height(ball.y, seen.ball_velocity.y, g, seen.ball_radius)
		if t_land < 0.0 or (ball.x + seen.ball_velocity.x * t_land) * facing >= 0.0:
			return none   # le ballon ne retombe pas dans notre camp
	var wanted := Enums.Role.DEFENDER
	var action := "receive"
	if n == 1:
		wanted = Enums.Role.SETTER
		action = "set"
	elif n == 2:
		wanted = Enums.Role.ATTACKER
		action = "attack"
	var meet_x := ball.x
	if n == 0:   # réception : on juge sur l'endroit où le ballon arrive à hauteur des bras
		var t_meet := Ballistics.time_to_height(ball.y, seen.ball_velocity.y, g, params.get_value(ParamIds.RECEIVE_ZONE_DY))
		if t_meet >= 0.0:
			meet_x = ball.x + seen.ball_velocity.x * t_meet
	var best := -1
	var best_score := INF
	for p in now.players:
		if p.team != team or (now.last_team == team and p.slot == now.last_slot):
			continue
		var score := absf(p.position.x - meet_x) - (1.5 if p.role == wanted else 0.0)
		if score < best_score:
			best_score = score
			best = p.slot
	return {"slot": best, "action": action}


# ------------------------------------------------------------------ actions
## Réception, passe ou service : se placer sous l'interception et appuyer au bon moment.
func _ground_action(slot: int, kind: StringName, now: MatchState, seen: MatchState, stay: bool, own_ball := false) -> PlayerIntent:
	var me := now.players[slot]
	var spec := ContactSpec.of(kind, params)
	var g: float = params.get_value(ParamIds.BALL_GRAVITY)
	var lag := (now.tick - seen.tick) * dt
	var t := Ballistics.time_to_height(seen.ball_position.y, seen.ball_velocity.y, g, spec.dy)
	if t < 0.0:
		t = Ballistics.time_to_height(seen.ball_position.y, seen.ball_velocity.y, g, seen.ball_radius + 0.05)
	if t < 0.0:
		return _go_home(slot, now)
	var x_int := seen.ball_position.x + seen.ball_velocity.x * t + (0.0 if own_ball else _pred_error[slot])
	var target_x := me.position.x if stay else x_int - me.facing * spec.dx
	var remaining := t - lag
	var press := me.action == Enums.ActionState.FREE or me.action == Enums.ActionState.SERVE_TOSS
	press = press and remaining - (spec.ideal + _timing_error[slot]) <= 0.0 and remaining > -spec.t_off
	var axis := _axis_to(me.position.x, target_x)
	return PlayerIntent.make(axis, false, press and kind == ContactSpec.RECEIVE, false,
		press and kind == ContactSpec.SET, press and kind == ContactSpec.SERVE)


## Saut puis smash (ou feinte) calés sur l'arrivée du ballon dans la zone de la main.
func _attack(slot: int, now: MatchState, seen: MatchState) -> PlayerIntent:
	var me := now.players[slot]
	var spec := ContactSpec.of(ContactSpec.FEINT if _feint[slot] else ContactSpec.SPIKE, params)
	var gp: float = params.get_value(ParamIds.PLAYER_GRAVITY)
	var apex: float = _apex_for(slot)
	var v0 := sqrt(2.0 * gp * apex)
	var g: float = params.get_value(ParamIds.BALL_GRAVITY)
	var lag := (now.tick - seen.tick) * dt
	var t := Ballistics.time_to_height(seen.ball_position.y, seen.ball_velocity.y, g, apex + spec.dy - 0.15)
	if t < 0.0:
		return _ground_action(slot, ContactSpec.RECEIVE, now, seen, false)
	var x_int := seen.ball_position.x + seen.ball_velocity.x * t + _pred_error[slot]
	var target_x := x_int - me.facing * spec.dx
	var contact_t := t - lag
	var axis := _axis_to(me.position.x, target_x)
	if me.action == Enums.ActionState.FREE:
		var jump_in := contact_t - spec.ideal - v0 / gp - _timing_error[slot]
		var close := absf(target_x - me.position.x) < 0.6
		return PlayerIntent.make(axis, jump_in <= 0.0 and close and contact_t > 0.0)
	if me.action == Enums.ActionState.AIR:
		var swing := contact_t - spec.ideal - _timing_error[slot] <= 0.0
		return PlayerIntent.make(axis, swing and not _feint[slot], swing and _feint[slot])
	return PlayerIntent.make(axis)


## Contre (attaquant, sur la passe adverse) ou retour au poste.
func _block_or_formation(slot: int, now: MatchState, seen: MatchState) -> PlayerIntent:
	var me := now.players[slot]
	var opp := 1 - me.team
	var blocking := _block[slot] and me.role == Enums.Role.ATTACKER and now.last_team == opp \
		and now.touches[opp] >= 2 and seen.ball_position.x * me.facing > 0.0
	if not blocking:
		return _go_home(slot, now)
	var net_x := -me.facing * params.get_value(ParamIds.NET_ZONE) * 0.5
	var axis := _axis_to(me.position.x, net_x)
	match me.action:
		Enums.ActionState.FREE:
			return PlayerIntent.make(axis, false, absf(me.position.x) < params.get_value(ParamIds.NET_ZONE))
		Enums.ActionState.BLOCK_READY:
			var hitter_airborne := false
			for p in now.players:
				if p.team == opp and p.role == Enums.Role.ATTACKER and (p.action == Enums.ActionState.AIR or p.action == Enums.ActionState.SPIKE):
					hitter_airborne = true
			return PlayerIntent.make(axis, hitter_airborne, false, true)
	return PlayerIntent.make(axis)


func _go_home(slot: int, now: MatchState) -> PlayerIntent:
	var me := now.players[slot]
	var id := ParamIds.HOME_ATTACKER_X
	if me.role == Enums.Role.SETTER:
		id = ParamIds.HOME_SETTER_X
	elif me.role == Enums.Role.DEFENDER:
		id = ParamIds.HOME_DEFENDER_X
	return PlayerIntent.make(_axis_to(me.position.x, -me.facing * params.get_value(id)))


func _axis_to(x: float, target: float) -> float:
	var gap := target - x
	if absf(gap) < params.get_value(ParamIds.AI_POSITION_TOL):
		return 0.0
	return clampf(gap / 0.4, -1.0, 1.0)


## Hauteur d'apogée du saut du joueur (même conversion que la simulation).
func _apex_for(slot: int) -> float:
	return _stats_apex[slot] if slot < _stats_apex.size() else 1.5


## Donne à l'IA les hauteurs de saut des joueurs (lues dans les fiches de personnage).
func set_lineup(lineup: Array[CharacterDefinition]) -> void:
	_stats_apex = []
	for definition in lineup:
		_stats_apex.append(StatConversion.jump_apex(definition.stats, params))
