class_name MatchEvent
extends RefCounted
## Événement émis par la simulation pendant un tick. Lu par le rendu, le debug et les tests ;
## ne peut rien modifier. `details` contient des valeurs simples (nombres, chaînes, vecteurs).

enum Type {
	BALL_LAUNCHED,
	BALL_LANDED,
	PARAMS_APPLIED,
}

var type: int
var tick: int
var details: Dictionary = {}


static func make(event_type: int, at_tick: int, info: Dictionary = {}) -> MatchEvent:
	var e := MatchEvent.new()
	e.type = event_type
	e.tick = at_tick
	e.details = info
	return e


func type_name() -> String:
	return Type.keys()[type]


## Représentation textuelle stable (pour l'empreinte des journaux de test).
func to_text() -> String:
	var keys := details.keys()
	keys.sort()
	var parts := PackedStringArray()
	for k: Variant in keys:
		parts.append("%s=%s" % [k, details[k]])
	return "%d %s %s" % [tick, type_name(), " ".join(parts)]
