class_name AudioBank
extends RefCounted
## Sons prêts à jouer : pour chaque son de data/audio/cues.json, le fichier WAV/OGG s'il existe, sinon trois niveaux
## synthétisés (ProceduralSound). Remplacer un son provisoire = renseigner `file`, sans toucher au code.

var cues: Dictionary = {}          # id -> SoundCueDefinition
var _streams: Dictionary = {}      # id -> Array[AudioStream] (1 fichier ou 3 niveaux)
var issues: Array[LoadIssue] = []


static func load_default() -> AudioBank:
	var bank := AudioBank.new()
	bank.build(SoundCueLoader.load_cues(SoundCueLoader.DEFAULT_PATH, bank.issues))
	return bank


func build(definitions: Dictionary) -> void:
	cues = definitions
	_streams.clear()
	for id: String in cues:
		var cue: SoundCueDefinition = cues[id]
		var file_stream := _load_file(cue)
		if file_stream != null:
			_streams[id] = [file_stream]
			continue
		var tiers: Array[AudioStream] = []
		for tier in ProceduralSound.TIERS:
			tiers.append(ProceduralSound.to_stream(ProceduralSound.samples(cue, tier)))
		_streams[id] = tiers


func has_cue(id: String) -> bool:
	return _streams.has(id)


## Flux pour une intensité 0 → 1 (niveau synthétisé le plus proche, ou le fichier).
func stream_for(id: String, intensity: float) -> AudioStream:
	var list: Array = _streams.get(id, [])
	if list.is_empty():
		return null
	if list.size() == 1:
		return list[0]
	var best := 0
	for i in ProceduralSound.TIERS.size():
		if absf(ProceduralSound.TIERS[i] - intensity) < absf(ProceduralSound.TIERS[best] - intensity):
			best = i
	return list[best]


func uses_file(id: String) -> bool:
	return (_streams.get(id, []) as Array).size() == 1


func _load_file(cue: SoundCueDefinition) -> AudioStream:
	if cue.file == "":
		return null
	if not FileAccess.file_exists(cue.file):
		issues.append(LoadIssue.make(LoadIssue.Severity.WARNING, SoundCueLoader.DEFAULT_PATH, "%s.file" % cue.id,
			"fichier introuvable « %s » : son synthétisé utilisé" % cue.file))
		return null
	var stream: AudioStream = null
	if cue.file.get_extension().to_lower() == "ogg":
		stream = AudioStreamOggVorbis.load_from_file(cue.file)
	elif cue.file.get_extension().to_lower() == "wav":
		stream = AudioStreamWAV.load_from_file(cue.file)
	if stream == null:
		issues.append(LoadIssue.make(LoadIssue.Severity.WARNING, SoundCueLoader.DEFAULT_PATH, "%s.file" % cue.id,
			"fichier illisible « %s » (WAV ou OGG attendu) : son synthétisé utilisé" % cue.file))
	return stream
