class_name MorphologyDefinition
extends RefCounted
## Morphologie VISUELLE (rapport au gabarit standard, 1.0 = standard).
## V1 : n'a aucun effet sur la portée, les collisions, la vitesse, le saut ou les stats.
## `weight` est un indice de corpulence visuelle, pas une masse.

const FIELDS: Array[String] = ["height", "weight", "arm_span", "leg_length"]
const DEFAULT_VALUE := 1.0
const NORMAL_MIN := 0.85
const NORMAL_MAX := 1.15
const EXPERIMENTAL_MIN := 0.6
const EXPERIMENTAL_MAX := 1.5

var height := DEFAULT_VALUE
var weight := DEFAULT_VALUE
var arm_span := DEFAULT_VALUE
var leg_length := DEFAULT_VALUE


func get_value(field: String) -> float:
	return float(get(field))


func set_value(field: String, value: float) -> void:
	set(field, value)


func is_standard() -> bool:
	for field: String in FIELDS:
		if get_value(field) != DEFAULT_VALUE:
			return false
	return true
