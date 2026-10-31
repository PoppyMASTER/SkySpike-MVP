class_name SimContext
extends RefCounted
## Ce que MatchSim prête aux acteurs pendant un tick : paramètres, hasard, ballon, terrain,
## durée du pas et file d'événements. Les acteurs n'ont pas d'autre accès au monde.

var params: ParamStore
var rng: MatchRng
var ball: BallBody
var court: CourtGeometry
var dt := 0.0
var tick := 0
var events: Array[MatchEvent] = []


func emit(event_type: int, info: Dictionary = {}) -> void:
	events.append(MatchEvent.make(event_type, tick, info))


## Remet la file à zéro et renvoie son contenu.
func take_events() -> Array[MatchEvent]:
	var out := events
	events = []
	return out
