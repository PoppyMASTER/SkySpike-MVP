class_name ParamPreset
extends RefCounted
## Jeu de valeurs de paramètres. Peut être partiel : il s'applique par-dessus sa base.

const SCHEMA_VERSION := 1

var id: String
## Identifiant du preset de base ("" = valeurs par défaut des définitions).
var base := ""
var experimental := false
var notes := ""
var read_only := false
var values: Dictionary = {}   # StringName -> float


func to_dict() -> Dictionary:
	var out_values := {}
	for key: StringName in values:
		out_values[String(key)] = values[key]
	return {
		"schema_version": SCHEMA_VERSION,
		"id": id,
		"base": base,
		"experimental": experimental,
		"notes": notes,
		"values": out_values,
	}
