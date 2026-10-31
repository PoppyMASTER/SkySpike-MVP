class_name SoundCueLoader
extends RefCounted
## Lit data/audio/cues.json et produit les SoundCueDefinition typés (valeurs bornées, problèmes signalés).

const DEFAULT_PATH := "res://data/audio/cues.json"
const SCHEMA_VERSION := 1
const CUE_KEYS: Array[String] = ["id", "file", "volume_db", "pitch_jitter", "synth"]
const SYNTH_KEYS: Array[String] = [
	"duration_s", "tone_start_hz", "tone_end_hz", "tone_s", "tone_gain", "noise_s", "noise_gain", "noise_brightness",
	"click_hz", "click_gain",
]


## id -> SoundCueDefinition.
static func load_cues(path: String, issues: Array[LoadIssue]) -> Dictionary:
	var out := {}
	var root: Variant = JsonLoader.load_object(path, issues)
	if root == null:
		return out
	var reader := SchemaReader.new(path, root, issues)
	if not reader.check_version(SCHEMA_VERSION):
		return out
	if not root.get("cues") is Array:
		reader.error("cues", "liste attendue")
		return out
	var list: Array = root.cues
	for i in list.size():
		if not list[i] is Dictionary:
			reader.error("cues[%d]" % i, "objet attendu")
			continue
		var cue := _read_cue(SchemaReader.new(path, list[i], issues, "cues[%d]" % i))
		if cue == null:
			continue
		if out.has(cue.id):
			reader.error("cues[%d].id" % i, "identifiant en double : %s" % cue.id)
			continue
		out[cue.id] = cue
	return out


static func _read_cue(r: SchemaReader) -> SoundCueDefinition:
	r.warn_unknown_keys(CUE_KEYS)
	var cue := SoundCueDefinition.new()
	cue.id = r.require_string("id", "^[a-z0-9_]+$")
	if cue.id == "":
		return null
	cue.file = r.optional_string("file", "")
	cue.volume_db = r.read_float("volume_db", -40.0, 6.0, 0.0, false).value
	cue.pitch_jitter = r.read_float("pitch_jitter", 0.0, 0.3, 0.0, false).value
	var s := r.child_object("synth")
	if s == null:
		return cue
	s.warn_unknown_keys(SYNTH_KEYS)
	cue.duration_s = s.read_float("duration_s", 0.02, 2.0, cue.duration_s, false).value
	cue.tone_start_hz = s.read_float("tone_start_hz", 20.0, 8000.0, cue.tone_start_hz, false).value
	cue.tone_end_hz = s.read_float("tone_end_hz", 20.0, 8000.0, cue.tone_end_hz, false).value
	cue.tone_s = s.read_float("tone_s", 0.0, 2.0, cue.tone_s, false).value
	cue.tone_gain = s.read_float("tone_gain", 0.0, 1.0, cue.tone_gain, false).value
	cue.noise_s = s.read_float("noise_s", 0.0, 2.0, cue.noise_s, false).value
	cue.noise_gain = s.read_float("noise_gain", 0.0, 1.0, cue.noise_gain, false).value
	cue.noise_brightness = s.read_float("noise_brightness", 0.01, 1.0, cue.noise_brightness, false).value
	cue.click_hz = s.read_float("click_hz", 20.0, 12000.0, cue.click_hz, false).value
	cue.click_gain = s.read_float("click_gain", 0.0, 1.0, cue.click_gain, false).value
	return cue
