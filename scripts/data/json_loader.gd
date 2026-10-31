class_name JsonLoader
extends RefCounted
## Lecture brute d'un fichier JSON. Ne valide pas le contenu (voir SchemaReader).

## Renvoie le dictionnaire racine, ou null en ajoutant le problème à `issues`.
static func load_object(path: String, issues: Array[LoadIssue]) -> Variant:
	if not FileAccess.file_exists(path):
		issues.append(LoadIssue.make(LoadIssue.Severity.ERROR, path, "", "fichier introuvable"))
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		issues.append(LoadIssue.make(LoadIssue.Severity.ERROR, path, "",
			"JSON invalide ligne %d : %s" % [json.get_error_line(), json.get_error_message()]))
		return null
	if not json.data is Dictionary:
		issues.append(LoadIssue.make(LoadIssue.Severity.ERROR, path, "", "la racine doit être un objet JSON"))
		return null
	return json.data


## Fichiers .json d'un dossier (non récursif), triés pour un ordre de chargement stable.
static func list_json_files(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir_path):
		return out
	for name: String in DirAccess.get_files_at(dir_path):
		if name.ends_with(".json"):
			out.append(dir_path.path_join(name))
	out.sort()
	return out


static func save_object(path: String, data: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	return OK
