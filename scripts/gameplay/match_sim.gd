class_name MatchSim
extends RefCounted
## Seul système autoritaire de la simulation. Avance d'un pas fixe à chaque appel de tick().
## N'utilise ni temps réel, ni delta d'image, ni hasard hors MatchRng.
##
## J1 : contient seulement le ballon et un « exercice de lancer » (le ballon est relancé
## au hasard quand il touche le sol) pour démontrer la boucle fixe et la reproductibilité.
## Cet exercice disparaît au J3, remplacé par le service et le rallye.

const DRILL_START := Vector2(-6.0, 1.0)

var params: ParamStore
var rng: MatchRng
var dt: float
var tick_count := 0
var ball := BallBody.new()

## Paramètres structurels figés (appliqués au prochain rallye ; en J1 : au prochain lancer).
var _rally_params: Dictionary = {}
var _events: Array[MatchEvent] = []


func _init(param_store: ParamStore, seed_value: int, tick_dt: float) -> void:
	params = param_store
	rng = MatchRng.new(seed_value)
	dt = tick_dt
	_freeze_rally_params()
	_launch_drill_ball()


## Un pas de simulation. Renvoie les événements produits depuis le pas précédent
## (le premier appel inclut ceux de l'initialisation, datés du tick 0).
func tick() -> Array[MatchEvent]:
	tick_count += 1
	ball.step(dt, params.get_value(ParamIds.BALL_GRAVITY), params.get_value(ParamIds.AIR_DRAG))
	if ball.position.y <= ball.radius and ball.velocity.y < 0.0:
		_emit(MatchEvent.Type.BALL_LANDED, {"x": snappedf(ball.position.x, 0.001)})
		_freeze_rally_params()
		_launch_drill_ball()
	var out := _events
	_events = []
	return out


func state() -> MatchState:
	var s := MatchState.new()
	s.tick = tick_count
	s.seed_value = rng.master_seed
	s.ball_position = ball.position
	s.ball_velocity = ball.velocity
	s.ball_radius = ball.radius
	return s


func _freeze_rally_params() -> void:
	var before := _rally_params.duplicate()
	_rally_params = {ParamIds.BALL_RADIUS: params.get_value(ParamIds.BALL_RADIUS)}
	ball.radius = _rally_params[ParamIds.BALL_RADIUS]
	if not before.is_empty() and before != _rally_params:
		_emit(MatchEvent.Type.PARAMS_APPLIED, {"ball_radius": ball.radius})


func _launch_drill_ball() -> void:
	var speed := rng.range_tagged(MatchRng.STREAM_MISC, "drill_speed",
		params.get_value(ParamIds.DRILL_SPEED_MIN), params.get_value(ParamIds.DRILL_SPEED_MAX))
	var angle := rng.range_tagged(MatchRng.STREAM_MISC, "drill_angle",
		params.get_value(ParamIds.DRILL_ANGLE_MIN), params.get_value(ParamIds.DRILL_ANGLE_MAX))
	ball.position = DRILL_START
	ball.velocity = Vector2(cos(angle), sin(angle)) * speed
	_emit(MatchEvent.Type.BALL_LAUNCHED, {"speed": snappedf(speed, 0.001), "angle": snappedf(angle, 0.0001)})


func _emit(event_type: int, info: Dictionary) -> void:
	_events.append(MatchEvent.make(event_type, tick_count, info))
