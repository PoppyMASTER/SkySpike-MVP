class_name MatchRunner
extends Node
## Racine d'un match (script de scenes/match/match.tscn). Seul endroit qui assemble
## simulation, horloge, rendu et debug. Possède l'accumulateur à pas fixe.

signal events_emitted(events: Array[MatchEvent])
signal restarted(seed_value: int)

const EVENT_LOG_SIZE := 60
const METRIC_SMOOTHING := 0.1

@export var start_seed := 1

var data: GameData
@onready var view: MatchView = get_node_or_null("MatchView")
var sim: MatchSim
var clock: SimClock
var previous_state: MatchState
var current_state: MatchState
var event_log: Array[MatchEvent] = []
## Tampon des entrées humaines (un seul joueur contrôlé).
var input := InputLatch.new()
var ai: AiDirector
## Slot du joueur contrôlé : 0 attaquant, 1 passeur, 2 défenseur (équipe bleue) ; -1 = IA contre IA.
@export var human_slot := 0

## Métriques mesurées (affichées par le diagnostic).
var fps := 0.0
var frame_ms := 0.0
var sim_us_per_tick := 0.0
var ticks_last_frame := 0


func _ready() -> void:
	if data == null:
		data = GameData.load_default()
	InputMapper.register_actions()
	restart(start_seed)


## Nouveau match avec cette graine ; applique aussi les paramètres « prochain match ».
func restart(seed_value: int) -> void:
	clock = SimClock.new(data.params.get_value(ParamIds.SIM_HZ))
	var lineup := MatchConfig.default_lineup(data.characters)
	if lineup.size() != 6:
		GameLog.error("Match", "%d personnage(s) disponible(s) : il en faut six, match en mode libre" % lineup.size())
	sim = MatchSim.new(data.params, seed_value, clock.dt, lineup, human_slot)
	ai = AiDirector.new(data.params, seed_value, clock.dt, human_slot)
	ai.set_lineup(lineup)
	input = InputLatch.new()
	current_state = sim.state()
	previous_state = current_state
	event_log.clear()
	if view != null:
		view.params = data.params
		view.setup_players(data.clips, lineup)
	restarted.emit(seed_value)
	GameLog.info("Match", "nouveau match, graine %d, %d ticks/s" % [seed_value, roundi(1.0 / clock.dt)])


func _process(delta: float) -> void:
	clock.time_scale = data.params.get_value(ParamIds.TIME_SCALE)
	clock.max_frame_s = data.params.get_value(ParamIds.MAX_FRAME_S)
	clock.max_ticks_per_frame = int(data.params.get_value(ParamIds.MAX_TICKS_PER_FRAME))
	InputMapper.poll(input)
	if clock.paused:
		input.clear_presses()
	var steps := clock.advance(delta)
	var t0 := Time.get_ticks_usec()
	for i in steps:
		run_one_tick()
	if steps > 0:
		var per_tick := float(Time.get_ticks_usec() - t0) / steps
		sim_us_per_tick = lerpf(sim_us_per_tick, per_tick, METRIC_SMOOTHING) if sim_us_per_tick > 0.0 else per_tick
	ticks_last_frame = steps
	if delta > 0.0:
		frame_ms = lerpf(frame_ms, delta * 1000.0, METRIC_SMOOTHING) if frame_ms > 0.0 else delta * 1000.0
	fps = Engine.get_frames_per_second()
	if view != null:
		view.show_states(previous_state, current_state, render_alpha())


## Un tick complet. Public pour les tests et le mode pas à pas.
## Sans argument : l'IA joue les slots non pilotés, le clavier ou la manette le slot humain.
func run_one_tick(intents: Array[PlayerIntent] = []) -> void:
	previous_state = current_state
	if intents.is_empty() and not sim.actors.is_empty():
		intents = ai.intents(current_state)
		if human_slot >= 0 and human_slot < intents.size():
			intents[human_slot] = input.consume()
	var events := sim.tick(intents)
	clock.on_tick_done()
	current_state = sim.state()
	if not events.is_empty():
		event_log.append_array(events)
		while event_log.size() > EVENT_LOG_SIZE:
			event_log.pop_front()
		events_emitted.emit(events)
		if view != null:
			view.on_events(events, current_state)


func set_paused(paused: bool) -> void:
	clock.paused = paused


func is_paused() -> bool:
	return clock.paused


func step_once() -> void:
	if clock.paused:
		clock.request_single_step()


## Fraction de tick écoulée pour l'interpolation du rendu.
func render_alpha() -> float:
	return 0.0 if clock.paused else clock.alpha()
