class_name MatchAudio
extends Node
## Sons de frappe du match (J4.1 SJ2). Écoute les événements déjà produits par la simulation et n'y écrit jamais :
## aucune règle, aucun contact, aucune physique ne dépend du son.
## - un son par contact de service RÉEL (sol / flottant / smash), aucun pour une frappe manquée ;
## - volume selon l'intensité réelle (HitIntensity : vitesse × qualité), niveau sourd pour une frappe molle ;
## - plafond de voix simultanées (la plus ancienne est coupée), contacts rapprochés fusionnés (le plus fort gagne),
##   bus « Effets » protégé par un limiteur (pas de pic au-delà de −1 dBFS) ;
## - pause : sons suspendus ; ralenti : hauteur qui suit la vitesse de simulation (réglable) ;
## - variation de hauteur tirée du numéro de tick : aucun hasard.

const BUS_NAME := "Effets"
const LIMITER_CEILING_DB := -1.0
const MIN_PITCH := 0.25
const LOG_SIZE := 64

var params: ParamStore
var bank: AudioBank
## Derniers sons joués (pour les tests et le diagnostic) : {cue, tick, time, volume_db, pitch, intensity}.
var played: Array[Dictionary] = []
var _voices: Array[AudioStreamPlayer] = []
var _voice_started: Array[float] = []
var _voice_volume: Array[float] = []
## Fin prévue du son de chaque voix (temps de simulation) : occupation déterministe, indépendante du pilote audio.
var _voice_end: Array[float] = []
var _now := 0.0
var _last_time := -INF
var _last_volume := -INF
var _last_voice := -1
var _paused := false


func _init(store: ParamStore = null, sound_bank: AudioBank = null) -> void:
	params = store
	bank = sound_bank


func _ready() -> void:
	if bank == null:
		bank = AudioBank.load_default()
		for issue in bank.issues:
			issue.write_to_log()
	ensure_bus()


## Bus « Effets » (créé une fois) avec un limiteur dur : jamais de pic au-dessus du plafond.
static func ensure_bus() -> int:
	var index := AudioServer.get_bus_index(BUS_NAME)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, BUS_NAME)
	AudioServer.set_bus_send(index, &"Master")
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = LIMITER_CEILING_DB
	AudioServer.add_bus_effect(index, limiter)
	return index


func reset() -> void:
	for v in _voices:
		v.stop()
	for i in _voice_end.size():
		_voice_end[i] = -INF
	played.clear()
	_last_time = -INF
	_last_volume = -INF
	_last_voice = -1


func set_paused(paused: bool) -> void:
	_paused = paused
	for v in _voices:
		v.stream_paused = paused


func is_paused() -> bool:
	return _paused


func voice_count() -> int:
	return _voices.size()


## Voix occupées à l'instant du dernier son joué.
func playing_count() -> int:
	var n := 0
	for end in _voice_end:
		if end > _now:
			n += 1
	return n


## Appelé par MatchRunner avec les événements d'un tick.
func on_events(events: Array[MatchEvent], state: MatchState) -> void:
	if params == null or bank == null or params.get_value(ParamIds.AUDIO_ENABLED) < 0.5:
		return
	for e in events:
		if e.type != MatchEvent.Type.CONTACT:
			continue
		var kind := String(e.details.get("serve_kind", ""))   # type CONFIRMÉ au contact
		if kind == "" or not bank.has_cue("serve_" + kind):
			continue
		_play("serve_" + kind, float(e.details.get("speed", 0.0)), float(e.details.get("q", 1.0)), kind, state)


func _play(id: String, speed: float, quality: float, kind: String, state: MatchState) -> void:
	var cue: SoundCueDefinition = bank.cues[id]
	var intensity := HitIntensity.compute(speed, quality, kind, params)
	var now := float(state.tick) * state.tick_seconds
	var volume := params.get_value(ParamIds.AUDIO_VOLUME_DB) + cue.volume_db - params.get_value(ParamIds.AUDIO_INTENSITY_RANGE_DB) * (1.0 - intensity)
	var interval: float = params.get_value(ParamIds.AUDIO_MIN_INTERVAL_S)
	var voice := -1
	if now - _last_time < interval and _last_voice >= 0:
		if volume <= _last_volume:
			return   # contact rapproché moins fort : fusionné avec le précédent
		voice = _last_voice   # contact rapproché plus fort : il remplace le précédent sur la même voix
	if voice < 0:
		voice = _free_voice(now)
	var player := _voices[voice]
	var pitch := 1.0 + cue.pitch_jitter * _tick_noise(state.tick)
	if params.get_value(ParamIds.AUDIO_SLOWMO_PITCH) >= 0.5:
		pitch *= clampf(params.get_value(ParamIds.TIME_SCALE), MIN_PITCH, 1.0)
	var stream := bank.stream_for(id, intensity)
	player.stop()
	player.stream = stream
	player.volume_db = volume
	player.pitch_scale = maxf(pitch, MIN_PITCH)
	if player.is_inside_tree():
		player.play()
		player.stream_paused = _paused
	_now = now
	_voice_started[voice] = now
	_voice_end[voice] = now + stream.get_length() / player.pitch_scale
	_voice_volume[voice] = volume
	_last_time = now
	_last_volume = volume
	_last_voice = voice
	played.append({"cue": id, "tick": state.tick, "time": now, "volume_db": volume, "pitch": player.pitch_scale, "intensity": intensity})
	while played.size() > LOG_SIZE:
		played.pop_front()


## Voix libre, sinon la plus ancienne (plafond `audio_max_voices`).
func _free_voice(now: float) -> int:
	var wanted := int(params.get_value(ParamIds.AUDIO_MAX_VOICES))
	while _voices.size() > wanted:
		var extra: AudioStreamPlayer = _voices.pop_back()
		_voice_started.pop_back()
		_voice_volume.pop_back()
		_voice_end.pop_back()
		extra.queue_free()
		_last_voice = -1
	for i in _voices.size():
		if _voice_end[i] <= now:
			return i
	if _voices.size() < wanted:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_NAME
		add_child(player)
		_voices.append(player)
		_voice_started.append(now)
		_voice_volume.append(-INF)
		_voice_end.append(now)
		return _voices.size() - 1
	var oldest := 0
	for i in _voices.size():
		if _voice_started[i] < _voice_started[oldest]:
			oldest = i
	return oldest


## Valeur dans [−1, 1] fixée par le numéro de tick (variation de hauteur reproductible).
static func _tick_noise(tick: int) -> float:
	var h := (tick * 2654435761) & 0xffff
	return float(h) / 32767.5 - 1.0
