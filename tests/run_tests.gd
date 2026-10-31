extends SceneTree
## Exécuteur de tests sans module externe.
## Usage : godot --headless --path . -s tests/run_tests.gd [-- filtre]
## Code de sortie 0 si tout passe, 1 sinon.

const TEST_DIRS: Array[String] = ["res://tests/unit", "res://tests/integration"]


func _initialize() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		filter = args[0]
	GameLog.echo_to_console = false
	var passed := 0
	var failed := 0
	var started := Time.get_ticks_msec()
	for dir: String in TEST_DIRS:
		for file: String in _test_files(dir):
			if filter != "" and not file.contains(filter):
				continue
			var script: GDScript = load(file)
			if script == null:
				print("ÉCHEC  %s : impossible de charger le script" % file)
				failed += 1
				continue
			for method: Dictionary in script.get_script_method_list():
				var name: String = method.name
				if not name.begins_with("test_"):
					continue
				var test: TestCase = script.new()
				test.current_test = name
				GameLog.clear()
				test.call(name)
				if test.failures.is_empty():
					passed += 1
				else:
					failed += 1
					print("ÉCHEC  %s::%s" % [file.get_file(), name])
					for f: String in test.failures:
						print("        " + f)
	print("\n%d test(s) réussi(s), %d échec(s) en %d ms" % [passed, failed, Time.get_ticks_msec() - started])
	quit(0 if failed == 0 else 1)


func _test_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f: String in DirAccess.get_files_at(dir):
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir.path_join(f))
	out.sort()
	return out
