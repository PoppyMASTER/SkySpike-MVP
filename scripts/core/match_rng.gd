class_name MatchRng
extends RefCounted
## Unique source de hasard de la simulation. Une graine maître produit des flux séparés
## (contacts, IA, divers) : modifier l'IA ne décale pas les tirages des contacts.
## Chaque tirage porte une étiquette et peut être journalisé (mode trace).

const STREAM_CONTACTS := &"contacts"
const STREAM_AI := &"ai"
const STREAM_MISC := &"misc"
const STREAMS: Array[StringName] = [STREAM_CONTACTS, STREAM_AI, STREAM_MISC]

var master_seed: int
var trace_enabled := false
## Tirages journalisés : {stream, tag, value}
var trace: Array[Dictionary] = []

var _streams: Dictionary = {}


func _init(seed_value: int) -> void:
	master_seed = seed_value
	for stream: StringName in STREAMS:
		var rng := RandomNumberGenerator.new()
		rng.seed = derive_seed(seed_value, String(stream))
		_streams[stream] = rng


## Graine d'un flux : dépend seulement de la graine maître et du nom du flux.
static func derive_seed(seed_value: int, stream_name: String) -> int:
	return hash([seed_value, stream_name])


## Nombre dans [0, 1).
func randf_tagged(stream: StringName, tag: String) -> float:
	return _record(stream, tag, _rng(stream).randf())


func range_tagged(stream: StringName, tag: String, from: float, to: float) -> float:
	return _record(stream, tag, _rng(stream).randf_range(from, to))


## Tirage gaussien centré, d'écart-type sigma.
func gaussian_tagged(stream: StringName, tag: String, sigma: float) -> float:
	return _record(stream, tag, _rng(stream).randfn(0.0, sigma))


## État interne d'un flux (pour sauvegarder / reprendre exactement une séquence).
func stream_state(stream: StringName) -> int:
	return _rng(stream).state


func _rng(stream: StringName) -> RandomNumberGenerator:
	assert(_streams.has(stream), "Flux de hasard inconnu : %s" % stream)
	return _streams[stream]


func _record(stream: StringName, tag: String, value: float) -> float:
	if trace_enabled:
		trace.append({"stream": stream, "tag": tag, "value": value})
	return value
