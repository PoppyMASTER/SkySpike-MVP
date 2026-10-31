class_name TestCase
extends RefCounted
## Base des tests. Chaque méthode `test_*` est appelée par tests/run_tests.gd.
## Les assertions n'arrêtent pas le test : elles enregistrent l'échec avec un message clair.

var failures: PackedStringArray = []
var current_test := ""


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append("%s : %s" % [current_test, message])


func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s : %s (obtenu %s, attendu %s)" % [current_test, message, actual, expected])


func assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s : %s (obtenu %s, attendu %s ± %s)" % [current_test, message, actual, expected, tolerance])


## Écrit un fichier JSON de test (dossiers créés au besoin).
static func write_json(path: String, data: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(data if data is String else JSON.stringify(data))


## Supprime récursivement un dossier de test.
static func remove_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub: String in DirAccess.get_directories_at(path):
		remove_dir(path.path_join(sub))
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


## Paramètres réels du projet (data/params/param_defs.json).
static func real_params() -> ParamStore:
	var issues: Array[LoadIssue] = []
	return ParamStore.new(ParamDefLoader.load_defs(ParamDefLoader.DEFAULT_PATH, issues))
