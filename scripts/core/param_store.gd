class_name ParamStore
extends RefCounted
## Source unique de toutes les valeurs réglables. Aucune valeur de gameplay ne doit être
## écrite en dur ailleurs : on lit ici, par identifiant déclaré dans ParamIds.

signal value_changed(id: StringName, value: float)
signal experimental_changed(enabled: bool)

enum SetResult { ACCEPTED, REJECTED_OUT_OF_RANGE, UNKNOWN_PARAM }

var experimental_mode := false:
	set(enabled):
		experimental_mode = enabled
		experimental_changed.emit(enabled)

var _defs: Dictionary = {}     # StringName -> ParamDef
var _order: Array[StringName] = []
var _values: Dictionary = {}   # StringName -> float


func _init(defs: Array[ParamDef]) -> void:
	for def: ParamDef in defs:
		_defs[def.id] = def
		_order.append(def.id)
		_values[def.id] = def.default_value


func has(id: StringName) -> bool:
	return _defs.has(id)


func get_def(id: StringName) -> ParamDef:
	return _defs.get(id)


func ids() -> Array[StringName]:
	return _order.duplicate()


func get_value(id: StringName) -> float:
	if not _values.has(id):
		GameLog.error("ParamStore", "Paramètre inconnu lu : %s" % id)
		return 0.0
	return _values[id]


## Modifie une valeur. Hors bornes normales : refusé, sauf en mode expérimental
## (où seules les bornes expérimentales s'appliquent).
func set_value(id: StringName, value: float) -> int:
	var def: ParamDef = _defs.get(id)
	if def == null:
		GameLog.error("ParamStore", "Paramètre inconnu modifié : %s" % id)
		return SetResult.UNKNOWN_PARAM
	if def.is_integer:
		value = roundf(value)
	var allowed := def.is_in_experimental_range(value) if experimental_mode else def.is_in_normal_range(value)
	if not allowed:
		GameLog.warning("ParamStore", "%s = %s refusé (bornes %s)" % [id, value, _bounds_text(def)])
		return SetResult.REJECTED_OUT_OF_RANGE
	if _values[id] != value:
		_values[id] = value
		value_changed.emit(id, value)
	return SetResult.ACCEPTED


func reset(id: StringName) -> void:
	var def: ParamDef = _defs.get(id)
	if def != null:
		set_value(id, def.default_value)


func reset_all() -> void:
	for id: StringName in _order:
		reset(id)


func is_outside_normal(id: StringName) -> bool:
	var def: ParamDef = _defs.get(id)
	return def != null and not def.is_in_normal_range(get_value(id))


## Applique un preset (déjà résolu avec sa base). Renvoie la liste des problèmes rencontrés.
func apply_values(values: Dictionary, allow_experimental: bool) -> Array[String]:
	var issues: Array[String] = []
	var previous_mode := experimental_mode
	if allow_experimental:
		experimental_mode = true
	for key: StringName in values:
		var result := set_value(key, float(values[key]))
		if result == SetResult.UNKNOWN_PARAM:
			issues.append("paramètre inconnu : %s" % key)
		elif result == SetResult.REJECTED_OUT_OF_RANGE:
			issues.append("%s hors bornes : %s" % [key, values[key]])
	if not allow_experimental:
		experimental_mode = previous_mode
	return issues


## Copie figée de toutes les valeurs (lue par la simulation au début d'un rallye).
func snapshot() -> Dictionary:
	return _values.duplicate()


## Valeurs courantes sous forme de preset complet, pour l'export.
func to_preset(preset_id: String) -> ParamPreset:
	var preset := ParamPreset.new()
	preset.id = preset_id
	preset.experimental = experimental_mode
	preset.values = _values.duplicate()
	return preset


func _bounds_text(def: ParamDef) -> String:
	if experimental_mode:
		return "exp. %s–%s" % [def.experimental_min, def.experimental_max]
	return "%s–%s" % [def.min_value, def.max_value]
