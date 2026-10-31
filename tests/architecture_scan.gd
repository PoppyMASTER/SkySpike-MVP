class_name ArchitectureScan
extends RefCounted
## Analyse statique du code : couche de chaque script, classes qu'il référence,
## motifs interdits. Utilisé par tests/unit/test_architecture.gd.

## Couches autorisées pour chaque couche (voir docs/ARCHITECTURE.md).
const ALLOWED: Dictionary = {
	"core": [],
	"characters": ["core"],
	"data": ["core", "characters"],
	"simulation": ["core", "characters"],
	"gameplay": ["core", "characters", "simulation"],
	"input": ["core", "gameplay"],
	"ai": ["core", "characters", "simulation", "gameplay"],
	"animation": ["core", "data", "characters", "gameplay"],
	"rendering": ["core", "characters", "simulation", "gameplay", "animation"],
	"app": ["core", "data", "characters", "simulation", "gameplay", "input", "ai", "animation", "rendering"],
	"debug": ["core", "data", "characters", "simulation", "gameplay", "input", "ai", "animation", "rendering", "app"],
}

## Interdits dans les couches qui doivent rester déterministes.
const DETERMINISTIC_LAYERS: Array[String] = ["simulation", "gameplay", "ai", "animation"]
const FORBIDDEN_PATTERNS: Array[String] = [
	"\\brandf\\(", "\\brandi\\(", "\\brandomize\\(", "\\brandf_range\\(", "\\brandi_range\\(",
	"RandomNumberGenerator", "\\bTime\\.", "\\bOS\\.get_ticks", "_process\\(", "_physics_process\\(",
	"\\bdelta\\b", "RigidBody2D", "CharacterBody2D", "Area2D", "PhysicsServer2D",
]


static func script_files(root: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f: String in DirAccess.get_files_at(root):
		if f.ends_with(".gd"):
			out.append(root.path_join(f))
	for d: String in DirAccess.get_directories_at(root):
		out.append_array(script_files(root.path_join(d)))
	out.sort()
	return out


## "res://scripts/gameplay/match_sim.gd" -> "gameplay"
static func layer_of(path: String) -> String:
	var rel := path.trim_prefix("res://scripts/")
	return rel.get_slice("/", 0)


## Code sans commentaires ni chaînes de caractères (pour ne pas compter les mots du texte).
static func code_only(source: String) -> String:
	var no_strings := RegEx.create_from_string("\"(?:[^\"\\\\]|\\\\.)*\"").sub(source, "\"\"", true)
	var lines := PackedStringArray()
	for line: String in no_strings.split("\n"):
		var hash_pos := line.find("#")
		lines.append(line.substr(0, hash_pos) if hash_pos >= 0 else line)
	return "\n".join(lines)


## class_name -> couche, pour tous les scripts sous `root`.
static func class_layers(root: String) -> Dictionary:
	var out := {}
	var re := RegEx.create_from_string("(?m)^class_name\\s+(\\w+)")
	for path: String in script_files(root):
		var m := re.search(FileAccess.get_file_as_string(path))
		if m != null:
			out[m.get_string(1)] = layer_of(path)
	return out


## Liste des violations de dépendance, en clair. Les dépendances se font par class_name ;
## les chargements par chemin (load/preload de scripts) sont réservés à la couche app.
static func dependency_violations(root: String) -> PackedStringArray:
	var classes := class_layers(root)
	var out := PackedStringArray()
	for path: String in script_files(root):
		var layer := layer_of(path)
		if not ALLOWED.has(layer):
			out.append("%s : couche « %s » non déclarée" % [path, layer])
			continue
		var allowed: Array = ALLOWED[layer]
		var code := code_only(FileAccess.get_file_as_string(path))
		for cls: String in classes:
			var other: String = classes[cls]
			if other == layer or allowed.has(other):
				continue
			if RegEx.create_from_string("\\b%s\\b" % cls).search(code) != null:
				out.append("%s (%s) utilise %s (%s)" % [path.get_file(), layer, cls, other])
	return out


## Motifs interdits dans les couches déterministes.
static func determinism_violations(root: String) -> PackedStringArray:
	var out := PackedStringArray()
	for path: String in script_files(root):
		if not DETERMINISTIC_LAYERS.has(layer_of(path)):
			continue
		var code := code_only(FileAccess.get_file_as_string(path))
		for pattern: String in FORBIDDEN_PATTERNS:
			if RegEx.create_from_string(pattern).search(code) != null:
				out.append("%s : motif interdit %s" % [path.get_file(), pattern])
	return out

