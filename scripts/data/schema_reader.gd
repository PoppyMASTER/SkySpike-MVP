class_name SchemaReader
extends RefCounted
## Lecture validée d'un objet JSON : chaque accès vérifie type et bornes, et note
## le problème (fichier + chemin du champ) au lieu de planter. Les valeurs de repli
## sont fournies par l'appelant, qui décide du fallback.

var file: String
var data: Dictionary
var issues: Array[LoadIssue]
var prefix: String


func _init(file_path: String, object: Dictionary, issue_list: Array[LoadIssue], field_prefix := "") -> void:
	file = file_path
	data = object
	issues = issue_list
	prefix = field_prefix


func error(field: String, text: String) -> void:
	issues.append(LoadIssue.make(LoadIssue.Severity.ERROR, file, _path(field), text))


func warning(field: String, text: String) -> void:
	issues.append(LoadIssue.make(LoadIssue.Severity.WARNING, file, _path(field), text))


## Vérifie `schema_version`. Renvoie false si absente ou différente (fichier à rejeter).
func check_version(expected: int) -> bool:
	if not data.has("schema_version"):
		error("schema_version", "champ obligatoire manquant")
		return false
	var v: Variant = data.schema_version
	if not _is_number(v) or int(v) != expected:
		error("schema_version", "version %s non prise en charge (attendu : %d)" % [v, expected])
		return false
	return true


## Signale les champs non prévus (avertissement seulement).
func warn_unknown_keys(allowed: Array[String]) -> void:
	for key: Variant in data:
		if not allowed.has(String(key)):
			warning(String(key), "champ inconnu, ignoré")


func has(key: String) -> bool:
	return data.has(key)


## Chaîne obligatoire. Renvoie "" et note une erreur si absente ou invalide.
func require_string(key: String, pattern := "") -> String:
	if not data.has(key):
		error(key, "champ obligatoire manquant")
		return ""
	var v: Variant = data[key]
	if not v is String or String(v) == "":
		error(key, "chaîne non vide attendue, reçu : %s" % [v])
		return ""
	if pattern != "":
		var re := RegEx.create_from_string(pattern)
		if re.search(v) == null:
			error(key, "format invalide « %s » (attendu : %s)" % [v, pattern])
			return ""
	return v


## Chaîne facultative ; `fallback` si absente, erreur si présente mais invalide.
func optional_string(key: String, fallback := "") -> String:
	if not data.has(key):
		return fallback
	var v: Variant = data[key]
	if not v is String:
		error(key, "chaîne attendue, reçu : %s" % [v])
		return fallback
	return v


## Entier dans [min_v, max_v]. `ok` passe à false si absent ou invalide.
func read_int(key: String, min_v: int, max_v: int, fallback: int, required: bool) -> Dictionary:
	if not data.has(key):
		if required:
			error(key, "champ obligatoire manquant")
		return {"ok": false, "value": fallback}
	var v: Variant = data[key]
	if not _is_number(v) or float(v) != floorf(float(v)):
		error(key, "entier attendu, reçu : %s" % [v])
		return {"ok": false, "value": fallback}
	var i := int(v)
	if i < min_v or i > max_v:
		error(key, "%d hors bornes [%d, %d]" % [i, min_v, max_v])
		return {"ok": false, "value": fallback}
	return {"ok": true, "value": i}


## Réel dans [min_v, max_v].
func read_float(key: String, min_v: float, max_v: float, fallback: float, required: bool) -> Dictionary:
	if not data.has(key):
		if required:
			error(key, "champ obligatoire manquant")
		return {"ok": false, "value": fallback}
	var v: Variant = data[key]
	if not _is_number(v) or is_nan(float(v)) or is_inf(float(v)):
		error(key, "nombre attendu, reçu : %s" % [v])
		return {"ok": false, "value": fallback}
	var f := float(v)
	if f < min_v or f > max_v:
		error(key, "%s hors bornes [%s, %s]" % [f, min_v, max_v])
		return {"ok": false, "value": fallback}
	return {"ok": true, "value": f}


func read_bool(key: String, fallback: bool) -> bool:
	if not data.has(key):
		return fallback
	var v: Variant = data[key]
	if not v is bool:
		error(key, "booléen attendu, reçu : %s" % [v])
		return fallback
	return v


## Sous-objet facultatif ; null si absent ou invalide.
func child_object(key: String) -> SchemaReader:
	if not data.has(key):
		return null
	var v: Variant = data[key]
	if not v is Dictionary:
		error(key, "objet attendu")
		return null
	return SchemaReader.new(file, v, issues, _path(key))


func _path(field: String) -> String:
	return field if prefix == "" else "%s.%s" % [prefix, field]


static func _is_number(v: Variant) -> bool:
	return v is int or v is float
