class_name Referee
extends RefCounted
## Règles du volley : touches, fautes, atterrissages, points, rotation du serveur, fin de partie.
## Opère sur le RallyState du contexte ; n'agit jamais sur la physique.

var ctx: SimContext


func _init(context: SimContext) -> void:
	ctx = context


## Comptabilise un contact. Renvoie true si le point est attribué (faute).
func register_contact(contact: Dictionary) -> bool:
	var rally := ctx.rally
	var slot: int = contact.slot
	var team := ctx.actors[slot].team
	rally.contact_seq += 1
	if contact.block:
		# Touche de bloc : non comptée, et pas de double touche juste après.
		rally.touches[team] = 0
		_set_last(team, slot, true)
		ctx.emit(MatchEvent.Type.TOUCH_COUNTED, {"slot": slot, "team": team, "count": 0, "block": true})
		return false
	if contact.kind == "serve":
		rally.served = true
		rally.touches = [0, 0]
		_set_last(team, slot, false)
		ctx.emit(MatchEvent.Type.TOUCH_COUNTED, {"slot": slot, "team": team, "count": 0, "block": false})
		return false
	if rally.last_team == team:
		if rally.last_slot == slot and not rally.last_was_block:
			return _fault("double_touch", team)
		rally.touches[team] += 1
	else:
		rally.touches[team] = 1
	rally.touches[1 - team] = 0
	_set_last(team, slot, false)
	ctx.emit(MatchEvent.Type.TOUCH_COUNTED, {"slot": slot, "team": team, "count": rally.touches[team], "block": false})
	if rally.touches[team] > int(ctx.params.get_value(ParamIds.MAX_TOUCHES)):
		return _fault("too_many_touches", team)
	return false


## Le ballon touche le sol en `x`. Attribue le point.
func landing(x: float) -> void:
	var rally := ctx.rally
	var inside := absf(x) <= ctx.court.half_length
	ctx.emit(MatchEvent.Type.BALL_LANDED, {"x": snappedf(x, 0.001), "inside": inside})
	if not rally.served:
		_fault("service_fault", rally.serving_team)
	elif inside:
		var side_team := 0 if x < 0.0 else 1
		award_point(1 - side_team, "landed_in")
	else:
		_fault("out", rally.last_team if rally.last_team >= 0 else rally.serving_team)


## Point pour `winner`. Calcule le score, la fin de partie, et passe en POINT_AWARDED.
func award_point(winner: int, reason: String) -> void:
	var rally := ctx.rally
	rally.score[winner] += 1
	rally.point_winner = winner
	rally.fault_text = reason
	var target := int(ctx.params.get_value(ParamIds.TARGET_POINTS))
	var lead := rally.score[winner] - rally.score[1 - winner]
	if rally.score[winner] >= target and lead >= int(ctx.params.get_value(ParamIds.WIN_BY)):
		rally.winner = winner
	ctx.emit(MatchEvent.Type.POINT_AWARDED, {"winner": winner, "reason": reason,
		"score_0": rally.score[0], "score_1": rally.score[1]})
	set_phase(Enums.Phase.POINT_AWARDED)


func set_phase(phase: int) -> void:
	ctx.rally.phase = phase
	ctx.rally.phase_time = 0.0
	ctx.emit(MatchEvent.Type.PHASE_CHANGED, {"phase": Enums.phase_to_string(phase)})


## Qui sert au prochain rallye ? Le service change quand l'équipe qui ne servait pas marque,
## et le serveur de cette équipe passe au poste suivant (attaquant → passeur → défenseur).
func prepare_next_service() -> void:
	var rally := ctx.rally
	if rally.point_winner >= 0 and rally.point_winner != rally.serving_team:
		rally.serving_team = rally.point_winner
		_assign_server(rally.serving_team)
		ctx.emit(MatchEvent.Type.ROTATION, {"team": rally.serving_team, "server": rally.server_slot})
	rally.start_rally()


## Choisit le serveur de `team` et avance son compteur de rotation.
func _assign_server(team: int) -> void:
	var rally := ctx.rally
	var index := rally.server_index[team]
	rally.server_index[team] = (index + 1) % 3
	var members: Array[PlayerActor] = []
	for actor in ctx.actors:
		if actor.team == team:
			members.append(actor)
	rally.server_slot = members[index % members.size()].slot
	for member in members:
		if member.character.role == index:
			rally.server_slot = member.slot
			break


func initial_service(team: int) -> void:
	ctx.rally.serving_team = team
	_assign_server(team)


func _set_last(team: int, slot: int, was_block: bool) -> void:
	ctx.rally.last_team = team
	ctx.rally.last_slot = slot
	ctx.rally.last_was_block = was_block


func _fault(reason: String, faulty_team: int) -> bool:
	ctx.emit(MatchEvent.Type.FAULT, {"reason": reason, "team": faulty_team})
	award_point(1 - faulty_team, reason)
	return true
