class_name ParamDefLoader
extends RefCounted
## Lit data/params/param_defs.json et produit les ParamDef typés.

const DEFAULT_PATH := "res://data/params/param_defs.json"
const SCHEMA_VERSION := 1
const PARAM_KEYS: Array[String] = [
	"id", "group", "label", "unit", "default", "min", "max", "experimental_min",
	"experimental_max", "apply", "integer", "step", "description",
]


static func load_defs(path: String, issues: Array[LoadIssue]) -> Array[ParamDef]:
	var defs: Array[ParamDef] = []
	var root: Variant = JsonLoader.load_object(path, issues)
	if root == null:
		return defs
	var reader := SchemaReader.new(path, root, issues)
	if not reader.check_version(SCHEMA_VERSION):
		return defs
	if not root.get("params") is Array:
		reader.error("params", "liste attendue")
		return defs
	var seen := {}
	var list: Array = root.params
	for i in list.size():
		if not list[i] is Dictionary:
			reader.error("params[%d]" % i, "objet attendu")
			continue
		var def := _read_def(SchemaReader.new(path, list[i], issues, "params[%d]" % i))
		if def == null:
			continue
		if seen.has(def.id):
			reader.error("params[%d].id" % i, "identifiant en double : %s" % def.id)
			continue
		seen[def.id] = true
		defs.append(def)
	return defs


static func _read_def(r: SchemaReader) -> ParamDef:
	r.warn_unknown_keys(PARAM_KEYS)
	var id := r.require_string("id", "^[a-z0-9_]+$")
	var big := 1e9
	var min_v: Dictionary = r.read_float("min", -big, big, 0.0, true)
	var max_v: Dictionary = r.read_float("max", -big, big, 0.0, true)
	var def_v: Dictionary = r.read_float("default", -big, big, 0.0, true)
	if id == "" or not (min_v.ok and max_v.ok and def_v.ok):
		return null
	var def := ParamDef.new()
	def.id = StringName(id)
	def.group = r.optional_string("group", "divers")
	def.label = r.optional_string("label", id)
	def.unit = r.optional_string("unit", "")
	def.description = r.optional_string("description", "")
	def.min_value = min_v.value
	def.max_value = max_v.value
	def.default_value = def_v.value
	def.experimental_min = r.read_float("experimental_min", -big, big, def.min_value, false).value
	def.experimental_max = r.read_float("experimental_max", -big, big, def.max_value, false).value
	def.is_integer = r.read_bool("integer", false)
	def.step = r.read_float("step", 0.0, big, 0.01, false).value
	var apply := r.optional_string("apply", "immediate")
	if not ParamDef.APPLY_MODE_NAMES.has(apply):
		r.error("apply", "mode inconnu « %s »" % apply)
		return null
	def.apply_mode = ParamDef.APPLY_MODE_NAMES[apply]
	if def.min_value > def.max_value:
		r.error("min", "min > max")
		return null
	if not def.is_in_normal_range(def.default_value):
		r.error("default", "défaut %s hors des bornes normales" % def.default_value)
		return null
	if def.experimental_min > def.min_value or def.experimental_max < def.max_value:
		r.error("experimental_min", "les bornes expérimentales doivent englober les bornes normales")
		return null
	return def
