class_name SimContext
extends RefCounted
## Ce que MatchSim prête aux acteurs pendant un tick : paramètres, hasard, ballon, terrain,
## rallye, autres joueurs, durée du pas, file d'événements et contacts à comptabiliser.

var params: ParamStore
var rng: MatchRng
var ball: BallBody
var court: CourtGeometry
var rally := RallyState.new()
var actors: Array[PlayerActor] = []
## Ballon tenu dans la main du serveur (pas de physique) avant le lancer.
var ball_held := false
var human_slot := -1
var dt := 0.0
var tick := 0
var events: Array[MatchEvent] = []
## Contacts du tick : {slot, kind, block}. Traités par MatchSim (arbitre) après les acteurs.
var contacts: Array[Dictionary] = []


func emit(event_type: int, info: Dictionary = {}) -> void:
	events.append(MatchEvent.make(event_type, tick, info))


## Remet la file à zéro et renvoie son contenu.
func take_events() -> Array[MatchEvent]:
	var out := events
	events = []
	return out


func is_human(slot: int) -> bool:
	return slot == human_slot


## Un coéquipier du poste donné (ou le plus proche du filet à défaut). null s'il n'y en a pas.
func teammate_by_role(slot: int, role: int) -> PlayerActor:
	var me := actors[slot]
	var fallback: PlayerActor = null
	for other in actors:
		if other.team != me.team or other.slot == slot:
			continue
		if other.character.role == role:
			return other
		if fallback == null or absf(other.body.position.x) < absf(fallback.body.position.x):
			fallback = other
	return fallback
