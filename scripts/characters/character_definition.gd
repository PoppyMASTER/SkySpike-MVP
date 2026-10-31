class_name CharacterDefinition
extends RefCounted
## Personnage assemblé à partir de ses fichiers JSON validés. Immuable après chargement.

var id: String
var display_name: String
var role: int = Enums.Role.ATTACKER
var stats: StatsDefinition
var morphology: MorphologyDefinition
var animation_set: AnimationSetDefinition
## Fichiers d'origine (pour les diagnostics).
var source_files: PackedStringArray = []
## Replis appliqués pendant le chargement, en clair (ex. « morphologie standard »).
var fallbacks: PackedStringArray = []


func describe() -> String:
	var parts := PackedStringArray()
	for field: String in StatsDefinition.FIELDS:
		parts.append("%s %d" % [field, stats.get_stat(field)])
	return "%s (%s, %s) — %s" % [display_name, id, Enums.role_to_string(role), ", ".join(parts)]
