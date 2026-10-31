class_name StatsDefinition
extends RefCounted
## Statistiques d'un personnage, échelle 0–100. Aucune n'est une grandeur physique :
## la conversion passe par StatConversion et les paramètres réglables.

const MIN_STAT := 0
const MAX_STAT := 100
const FIELDS: Array[String] = [
	"attack_power", "receive", "block", "set_power",
	"set_accuracy", "spike_accuracy", "speed", "jump",
]

var attack_power := 50
var receive := 50
var block := 50
var set_power := 50
var set_accuracy := 50
var spike_accuracy := 50
var speed := 50
var jump := 50


func get_stat(field: String) -> int:
	return int(get(field))


func set_stat(field: String, value: int) -> void:
	set(field, clampi(value, MIN_STAT, MAX_STAT))


func copy() -> StatsDefinition:
	var out := StatsDefinition.new()
	for field: String in FIELDS:
		out.set_stat(field, get_stat(field))
	return out
