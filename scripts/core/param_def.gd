class_name ParamDef
extends RefCounted
## Déclaration d'un paramètre réglable (lue depuis data/params/param_defs.json).

enum ApplyMode { IMMEDIATE, NEXT_RALLY, NEXT_MATCH }

const APPLY_MODE_NAMES: Dictionary = {
	"immediate": ApplyMode.IMMEDIATE,
	"next_rally": ApplyMode.NEXT_RALLY,
	"next_match": ApplyMode.NEXT_MATCH,
}

var id: StringName
var group: String
var label: String
var unit: String
var description: String
var default_value: float
var min_value: float
var max_value: float
## Bornes élargies, accessibles seulement en mode expérimental.
var experimental_min: float
var experimental_max: float
var is_integer := false
var apply_mode: int = ApplyMode.IMMEDIATE
## Pas du curseur dans le panneau.
var step: float = 0.01


func clamp_normal(value: float) -> float:
	return clampf(value, min_value, max_value)


func is_in_normal_range(value: float) -> bool:
	return value >= min_value and value <= max_value


func is_in_experimental_range(value: float) -> bool:
	return value >= experimental_min and value <= experimental_max
