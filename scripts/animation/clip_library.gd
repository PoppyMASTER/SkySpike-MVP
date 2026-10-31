class_name ClipLibrary
extends RefCounted
## Clips et jeux d'animations chargés depuis `data/animations/`. Gère les remplacements par personnage et
## les replis : clip du perso → clip standard → clip « idle » → pose de repos (avec erreur journalisée une fois).

const SET_SCHEMA_VERSION := 1
const CLIPS_DIR := "animations/clips"
const SETS_DIR := "animations/sets"

var clips: Dictionary = {}          # id -> AnimationClip
var standard_actions: Dictionary = {}   # action -> id de clip (jeu standard_v1)
var issues: Array[LoadIssue] = []
var _rest_clips: Dictionary = {}
var _reported: Dictionary = {}


func load_all(data_root: String) -> void:
	clips.clear()
	standard_actions.clear()
	issues.clear()
	for path in JsonLoader.list_json_files(data_root.path_join(CLIPS_DIR)):
		var clip := AnimationClip.from_file(path, issues)
		if clip != null:
			clips[clip.id] = clip
	_load_standard_set(data_root.path_join(SETS_DIR).path_join(AnimationSetDefinition.STANDARD_SET + ".json"))


func clip_ids() -> PackedStringArray:
	var ids := PackedStringArray(clips.keys())
	ids.sort()
	return ids


func get_clip(id: String) -> AnimationClip:
	return clips.get(id)


## Clip à jouer pour `action` : remplacement du personnage s'il existe, sinon jeu standard, sinon repli.
func clip_for(anim_set: AnimationSetDefinition, action: String) -> AnimationClip:
	var id := anim_set.clip_for(action) if anim_set != null else ""
	if id != "" and clips.has(id):
		return clips[id]
	if id != "":
		_report_once("%s/%s" % [id, action], "clip « %s » (remplacement de %s) introuvable : clip standard utilisé" % [id, action])
	var standard_id: String = standard_actions.get(action, "")
	if standard_id != "" and clips.has(standard_id):
		return clips[standard_id]
	_report_once("standard/" + action, "aucun clip standard pour « %s » : pose de repos utilisée" % action)
	if not _rest_clips.has(action):
		_rest_clips[action] = AnimationClip.rest_clip("rest_" + action, action)
	return _rest_clips[action]


## Vérifie que les remplacements d'un personnage pointent vers des clips existants et de la bonne action.
func validate_overrides(character: CharacterDefinition, out: Array[LoadIssue]) -> void:
	var anim := character.animation_set
	for action: String in anim.overrides:
		var id: String = anim.overrides[action]
		var file := "characters/%s (animations)" % character.id
		if not clips.has(id):
			out.append(LoadIssue.make(LoadIssue.Severity.ERROR, file, "overrides." + action,
				"clip « %s » introuvable : clip standard utilisé" % id))
		elif (clips[id] as AnimationClip).action != action:
			out.append(LoadIssue.make(LoadIssue.Severity.WARNING, file, "overrides." + action,
				"le clip « %s » est prévu pour l'action « %s »" % [id, (clips[id] as AnimationClip).action]))


func _load_standard_set(path: String) -> void:
	var root: Variant = JsonLoader.load_object(path, issues)
	if root == null:
		return
	var r := SchemaReader.new(path, root, issues)
	if not r.check_version(SET_SCHEMA_VERSION):
		return
	r.warn_unknown_keys(["schema_version", "id", "actions"])
	var actions := r.child_object("actions")
	if actions == null:
		r.error("actions", "table action → clip obligatoire")
		return
	for action in AnimationSetDefinition.ACTIONS:
		var id := actions.require_string(action, AnimationClip.ID_PATTERN)
		if id == "":
			continue
		if not clips.has(id):
			actions.error(action, "clip « %s » introuvable" % id)
			continue
		if (clips[id] as AnimationClip).action != action:
			actions.warning(action, "le clip « %s » est prévu pour l'action « %s »" % [id, (clips[id] as AnimationClip).action])
		standard_actions[action] = id


func _report_once(key: String, text: String) -> void:
	if _reported.has(key):
		return
	_reported[key] = true
	GameLog.error("Animation", text)
