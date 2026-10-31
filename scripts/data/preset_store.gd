class_name PresetStore
extends RefCounted
## Presets de paramètres : ceux livrés avec le jeu (lecture seule, data/presets/) et ceux
## de l'utilisateur (user://presets/). Résout l'héritage `base` et exporte.

const BUILTIN_DIR := "res://data/presets"
const USER_DIR := "user://presets"
const MAX_BASE_DEPTH := 8

var presets: Dictionary = {}   # id -> ParamPreset
var issues: Array[LoadIssue] = []


func load_all(builtin_dir := BUILTIN_DIR, user_dir := USER_DIR) -> void:
	presets.clear()
	issues.clear()
	for path: String in JsonLoader.list_json_files(builtin_dir):
		_load_file(path, true)
	for path: String in JsonLoader.list_json_files(user_dir):
		_load_file(path, false)


func ids() -> Array:
	var out := presets.keys()
	out.sort()
	return out


## Valeurs complètes d'un preset, base comprise (la base d'abord, puis ses propres valeurs).
func resolve(id: String) -> Dictionary:
	var chain: Array[ParamPreset] = []
	var current := id
	while current != "" and chain.size() < MAX_BASE_DEPTH:
		var preset: ParamPreset = presets.get(current)
		if preset == null:
			GameLog.error("Presets", "preset introuvable : %s" % current)
			break
		chain.push_front(preset)
		current = preset.base
	var values := {}
	for preset: ParamPreset in chain:
		values.merge(preset.values, true)
	return values


func is_experimental(id: String) -> bool:
	var preset: ParamPreset = presets.get(id)
	return preset != null and preset.experimental


## Enregistre un preset utilisateur ; refuse d'écraser un preset livré avec le jeu.
func save_user(preset: ParamPreset, user_dir := USER_DIR) -> Error:
	var existing: ParamPreset = presets.get(preset.id)
	if existing != null and existing.read_only:
		GameLog.warning("Presets", "« %s » est en lecture seule, choisis un autre nom" % preset.id)
		return ERR_ALREADY_EXISTS
	var err := JsonLoader.save_object(user_dir.path_join(preset.id + ".json"), preset.to_dict())
	if err == OK:
		presets[preset.id] = preset
	return err


func _load_file(path: String, read_only: bool) -> void:
	var root: Variant = JsonLoader.load_object(path, issues)
	if root == null:
		return
	var r := SchemaReader.new(path, root, issues)
	if not r.check_version(ParamPreset.SCHEMA_VERSION):
		return
	r.warn_unknown_keys(["schema_version", "id", "base", "experimental", "notes", "values"])
	var id := r.require_string("id", "^[a-z0-9_]+$")
	if id == "":
		return
	if id != path.get_file().get_basename():
		r.error("id", "« %s » doit être égal au nom du fichier" % id)
		return
	var preset := ParamPreset.new()
	preset.id = id
	preset.read_only = read_only
	preset.base = r.optional_string("base", "")
	preset.experimental = r.read_bool("experimental", false)
	preset.notes = r.optional_string("notes", "")
	var values: Variant = root.get("values", {})
	if not values is Dictionary:
		r.error("values", "objet attendu")
		return
	for key: Variant in values:
		var v: Variant = values[key]
		if v is int or v is float:
			preset.values[StringName(String(key))] = float(v)
		else:
			r.error("values.%s" % key, "nombre attendu")
	presets[id] = preset
