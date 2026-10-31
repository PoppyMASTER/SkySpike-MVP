class_name CharacterRepository
extends RefCounted
## Charge tous les personnages de data/characters/ : fichier d'identité + stats +
## morphologie + ensemble d'animations, validés et convertis en CharacterDefinition.
## Règles de repli (voir docs/DATA_FORMATS.md) :
## - identité invalide → perso rejeté ;
## - stat manquante / invalide → valeur du gabarit de rôle ; fichier de stats illisible → gabarit entier ;
## - morphologie absente ou invalide → 1.0 par champ ;
## - ensemble d'animations absent ou invalide → standard_v1 sans remplacement.

const DATA_ROOT := "res://data"
const CHARACTERS_DIR := "characters"
const SCHEMA_VERSION := 1
const ID_PATTERN := "^[a-z0-9_]+$"
const ROLE_TEMPLATE_FORMAT := "characters/stats/_role_%s.json"
const CHARACTER_KEYS: Array[String] = [
	"schema_version", "id", "display_name", "role", "stats_ref", "morphology_ref",
	"animation_set_ref", "appearance_ref",
]

var data_root: String
var characters: Dictionary = {}   # id -> CharacterDefinition
var issues: Array[LoadIssue] = []
var _role_templates: Dictionary = {}   # role -> StatsDefinition


func _init(root := DATA_ROOT) -> void:
	data_root = root


func load_all() -> void:
	characters.clear()
	issues.clear()
	_role_templates.clear()
	for role: int in Enums.ROLE_NAMES:
		_role_templates[role] = _load_role_template(role)
	for path: String in JsonLoader.list_json_files(data_root.path_join(CHARACTERS_DIR)):
		var def := _load_character(path)
		if def == null:
			continue
		if characters.has(def.id):
			issues.append(LoadIssue.make(LoadIssue.Severity.ERROR, path, "id", "identifiant déjà utilisé : %s" % def.id))
			continue
		characters[def.id] = def


func ids() -> Array:
	var out := characters.keys()
	out.sort()
	return out


func get_character(id: String) -> CharacterDefinition:
	return characters.get(id)


func error_count() -> int:
	return issues.filter(func(i: LoadIssue) -> bool: return i.is_error()).size()


# ------------------------------------------------------------------ identité
func _load_character(path: String) -> CharacterDefinition:
	var root: Variant = JsonLoader.load_object(path, issues)
	if root == null:
		return null
	var r := SchemaReader.new(path, root, issues)
	if not r.check_version(SCHEMA_VERSION):
		return null
	r.warn_unknown_keys(CHARACTER_KEYS)
	var def := CharacterDefinition.new()
	def.id = r.require_string("id", ID_PATTERN)
	def.display_name = r.require_string("display_name")
	var role_text := r.require_string("role")
	def.role = Enums.role_from_string(role_text)
	if role_text != "" and def.role < 0:
		r.error("role", "rôle inconnu « %s » (attaquant : attacker, passeur : setter, défenseur : defender)" % role_text)
	var stats_ref := r.require_string("stats_ref")
	if def.id == "" or def.display_name == "" or def.role < 0 or stats_ref == "":
		r.error("", "personnage rejeté : identité incomplète")
		return null
	if def.id != path.get_file().get_basename():
		r.error("id", "« %s » doit être égal au nom du fichier" % def.id)
		return null
	def.source_files.append(path)
	def.stats = _load_stats(stats_ref, def)
	def.morphology = _load_morphology(r.optional_string("morphology_ref"), def)
	def.animation_set = _load_animation_set(r.optional_string("animation_set_ref"), def)
	if r.has("appearance_ref"):
		r.warning("appearance_ref", "apparence pas encore prise en charge (J4), ignorée")
	return def


# ------------------------------------------------------------------ stats
func _load_role_template(role: int) -> StatsDefinition:
	var path := data_root.path_join(ROLE_TEMPLATE_FORMAT % Enums.role_to_string(role))
	var stats := StatsDefinition.new()
	var root: Variant = JsonLoader.load_object(path, issues)
	if root == null:
		issues.append(LoadIssue.make(LoadIssue.Severity.WARNING, path, "", "gabarit de rôle absent : toutes les stats à 50"))
		return stats
	var r := SchemaReader.new(path, root, issues)
	if r.check_version(SCHEMA_VERSION):
		_read_stats(r, stats, StatsDefinition.new())
	return stats


func _load_stats(ref: String, def: CharacterDefinition) -> StatsDefinition:
	var template: StatsDefinition = _role_templates[def.role]
	var path := data_root.path_join(ref)
	var root: Variant = JsonLoader.load_object(path, issues)
	if root == null:
		def.fallbacks.append("stats : gabarit du rôle %s (fichier illisible)" % Enums.role_to_string(def.role))
		return template.copy()
	var r := SchemaReader.new(path, root, issues)
	if not r.check_version(SCHEMA_VERSION):
		def.fallbacks.append("stats : gabarit du rôle (version)")
		return template.copy()
	def.source_files.append(path)
	var stats := StatsDefinition.new()
	var replaced := _read_stats(r, stats, template)
	for field: String in replaced:
		def.fallbacks.append("stat %s : valeur du gabarit de rôle" % field)
	return stats


## Remplit `stats` ; un champ manquant ou invalide prend la valeur de `template`.
## Renvoie la liste des champs remplacés.
func _read_stats(r: SchemaReader, stats: StatsDefinition, template: StatsDefinition) -> PackedStringArray:
	var allowed: Array[String] = ["schema_version"]
	allowed.append_array(StatsDefinition.FIELDS)
	r.warn_unknown_keys(allowed)
	var replaced := PackedStringArray()
	for field: String in StatsDefinition.FIELDS:
		var res: Dictionary = r.read_int(field, StatsDefinition.MIN_STAT, StatsDefinition.MAX_STAT, template.get_stat(field), false)
		if not res.ok:
			replaced.append(field)
			if not r.has(field):
				r.warning(field, "stat manquante : valeur du gabarit de rôle (%d)" % template.get_stat(field))
		stats.set_stat(field, res.value)
	return replaced


# ------------------------------------------------------------------ morphologie
func _load_morphology(ref: String, def: CharacterDefinition) -> MorphologyDefinition:
	var morph := MorphologyDefinition.new()
	if ref == "":
		def.fallbacks.append("morphologie standard (aucun fichier)")
		return morph
	var path := data_root.path_join(ref)
	var root: Variant = JsonLoader.load_object(path, issues)
	if root == null:
		def.fallbacks.append("morphologie standard (fichier illisible)")
		return morph
	var r := SchemaReader.new(path, root, issues)
	if not r.check_version(SCHEMA_VERSION):
		def.fallbacks.append("morphologie standard (version)")
		return morph
	def.source_files.append(path)
	var allowed: Array[String] = ["schema_version"]
	allowed.append_array(MorphologyDefinition.FIELDS)
	r.warn_unknown_keys(allowed)
	for field: String in MorphologyDefinition.FIELDS:
		var res: Dictionary = r.read_float(field, MorphologyDefinition.EXPERIMENTAL_MIN,
			MorphologyDefinition.EXPERIMENTAL_MAX, MorphologyDefinition.DEFAULT_VALUE, false)
		morph.set_value(field, res.value)
		if res.ok and (res.value < MorphologyDefinition.NORMAL_MIN or res.value > MorphologyDefinition.NORMAL_MAX):
			r.warning(field, "%s hors de la plage normale [%s, %s] (accepté, valeur expérimentale)" % [
				res.value, MorphologyDefinition.NORMAL_MIN, MorphologyDefinition.NORMAL_MAX])
		if not res.ok and r.has(field):
			def.fallbacks.append("morphologie %s : 1.0" % field)
	return morph


# ------------------------------------------------------------------ animations
func _load_animation_set(ref: String, def: CharacterDefinition) -> AnimationSetDefinition:
	var anim := AnimationSetDefinition.new()
	if ref == "":
		def.fallbacks.append("animations standard (aucun fichier)")
		return anim
	var path := data_root.path_join(ref)
	var root: Variant = JsonLoader.load_object(path, issues)
	if root == null:
		def.fallbacks.append("animations standard (fichier illisible)")
		return anim
	var r := SchemaReader.new(path, root, issues)
	if not r.check_version(SCHEMA_VERSION):
		def.fallbacks.append("animations standard (version)")
		return anim
	def.source_files.append(path)
	r.warn_unknown_keys(["schema_version", "default_set", "overrides"])
	var set_name := r.optional_string("default_set", AnimationSetDefinition.STANDARD_SET)
	if set_name != AnimationSetDefinition.STANDARD_SET:
		r.error("default_set", "jeu inconnu « %s » : %s utilisé" % [set_name, AnimationSetDefinition.STANDARD_SET])
	var overrides := r.child_object("overrides")
	if overrides != null:
		for action: Variant in overrides.data:
			var action_name := String(action)
			if not AnimationSetDefinition.ACTIONS.has(action_name):
				overrides.error(action_name, "action inconnue, remplacement ignoré")
				continue
			var clip := overrides.require_string(action_name, ID_PATTERN)
			if clip != "":
				anim.overrides[action_name] = clip
	return anim
