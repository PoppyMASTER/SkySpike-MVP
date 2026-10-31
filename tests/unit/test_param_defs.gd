extends TestCase
## Les définitions réelles du projet sont valides et chaque paramètre est réellement utilisé.

const IDS_SCRIPT := "res://scripts/core/param_ids.gd"


func test_real_definitions_load_without_issue() -> void:
	var issues: Array[LoadIssue] = []
	var defs := ParamDefLoader.load_defs(ParamDefLoader.DEFAULT_PATH, issues)
	assert_eq(issues.size(), 0, "aucun problème dans param_defs.json : %s" % [issues.map(func(i: LoadIssue) -> String: return i.describe())])
	assert_true(defs.size() > 0, "au moins un paramètre")


func test_every_definition_has_a_constant_and_reverse() -> void:
	var issues: Array[LoadIssue] = []
	var defs := ParamDefLoader.load_defs(ParamDefLoader.DEFAULT_PATH, issues)
	var constants: Dictionary = (load(IDS_SCRIPT) as GDScript).get_script_constant_map()
	var declared := {}
	for def: ParamDef in defs:
		declared[def.id] = true
		assert_true(constants.has(String(def.id).to_upper()), "constante ParamIds manquante pour %s" % def.id)
	for name: String in constants:
		assert_true(declared.has(constants[name]), "ParamIds.%s ne correspond à aucune définition" % name)


func test_every_constant_is_used_in_code() -> void:
	var constants: Dictionary = (load(IDS_SCRIPT) as GDScript).get_script_constant_map()
	var code := ""
	for path: String in ArchitectureScan.script_files("res://scripts"):
		if path != IDS_SCRIPT:
			code += FileAccess.get_file_as_string(path)
	for name: String in constants:
		assert_true(code.contains("ParamIds.%s" % name), "ParamIds.%s déclaré mais jamais lu" % name)


func test_invalid_definition_is_rejected_with_message() -> void:
	var dir := "user://test_param_defs"
	remove_dir(dir)
	write_json(dir + "/defs.json", {"schema_version": 1, "params": [
		{"id": "ok_param", "default": 1, "min": 0, "max": 2},
		{"id": "bad_default", "default": 9, "min": 0, "max": 2},
		{"id": "Bad Id", "default": 1, "min": 0, "max": 2},
		{"id": "ok_param", "default": 1, "min": 0, "max": 2},
	]})
	var issues: Array[LoadIssue] = []
	var defs := ParamDefLoader.load_defs(dir + "/defs.json", issues)
	assert_eq(defs.size(), 1, "seul le paramètre valide est gardé")
	assert_eq(issues.size(), 3, "trois erreurs : défaut hors bornes, id invalide, doublon")
	remove_dir(dir)
