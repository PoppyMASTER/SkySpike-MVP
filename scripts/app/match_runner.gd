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

## Métriques mesurées (affichées par le diagnostic).
var fps := 0.0
var frame_ms := 0.0
var sim_us_per_tick := 0.0
var ticks_last_frame := 0


func _ready() -> void:
	if data == null:
		data = GameData.load_default()
	restart(start_seed)


## Nouveau match avec cette graine ; applique aussi les paramètres « prochain match ».
func restart(seed_value: int) -> void:
	clock = SimClock.new(data.params.get_value(ParamIds.SIM_HZ))
	sim = MatchSim.new(data.params, seed_value, clock.dt)
	current_state = sim.state()
	previous_state = current_state
	event_log.clear()
	restarted.emit(seed_value)
	GameLog.info("Match", "nouveau match, graine %d, %d ticks/s" % [seed_value, roundi(1.0 / clock.dt)])


func _process(delta: float) -> void:
	clock.time_scale = data.params.get_value(ParamIds.TIME_SCALE)
	clock.max_frame_s = data.params.get_value(ParamIds.MAX_FRAME_S)
	clock.max_ticks_per_frame = int(data.params.get_value(ParamIds.MAX_TICKS_PER_FRAME))
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
func run_one_tick() -> void:
	previous_state = current_state
	var events := sim.tick()
	clock.on_tick_done()
	current_state = sim.state()
	if not events.is_empty():
		event_log.append_array(events)
		while event_log.size() > EVENT_LOG_SIZE:
			event_log.pop_front()
		events_emitted.emit(events)


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
