extends TestCase
## Règles d'architecture vérifiées sur le code réel (docs/ARCHITECTURE.md).

const ROOT := "res://scripts"
const REVIEW_THRESHOLD_LINES := 300


func test_layers_only_use_allowed_layers() -> void:
	var violations := ArchitectureScan.dependency_violations(ROOT)
	assert_eq(violations.size(), 0, "dépendances interdites :\n  " + "\n  ".join(violations))


func test_deterministic_layers_have_no_forbidden_calls() -> void:
	var violations := ArchitectureScan.determinism_violations(ROOT)
	assert_eq(violations.size(), 0, "appels interdits :\n  " + "\n  ".join(violations))


func test_only_app_layer_loads_scripts_by_path() -> void:
	var re := RegEx.create_from_string("\\b(pre)?load\\(\"res://scripts/")
	for path: String in ArchitectureScan.script_files(ROOT):
		if ArchitectureScan.layer_of(path) == "app":
			continue
		assert_true(re.search(FileAccess.get_file_as_string(path)) == null,
			"%s charge un script par chemin (utiliser class_name)" % path.get_file())


func test_scanner_detects_a_forbidden_dependency() -> void:
	# Contrôle du contrôleur : le scanner doit bien voir une référence interdite.
	var code := ArchitectureScan.code_only("var v := MatchView.new() # commentaire MatchSim\nvar s := \"MatchRunner\"")
	assert_true(RegEx.create_from_string("\\bMatchView\\b").search(code) != null, "référence de code détectée")
	assert_true(RegEx.create_from_string("\\bMatchSim\\b").search(code) == null, "commentaire ignoré")
	assert_true(RegEx.create_from_string("\\bMatchRunner\\b").search(code) == null, "chaîne ignorée")


func test_scripts_over_review_threshold_are_listed() -> void:
	# Pas un échec : seuil de revue. La liste est imprimée pour décision humaine.
	for path: String in ArchitectureScan.script_files(ROOT):
		var n := FileAccess.get_file_as_string(path).count("\n")
		if n > REVIEW_THRESHOLD_LINES:
			print("        [revue] %s : %d lignes" % [path, n])
