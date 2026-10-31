class_name MatchSim
extends RefCounted
## Seul système autoritaire de la simulation. Avance d'un pas fixe à chaque appel de tick().
## N'utilise ni temps réel, ni durée d'image, ni hasard hors MatchRng.
##
## J2 : un ballon (avec filet à collision balayée) et au plus un joueur contrôlé.
## « L'exercice de lancer » du J1 relance le ballon quand il touche le sol, pour pouvoir
## s'entraîner ; il disparaît au J3, remplacé par le service et le rallye.
##
## Ordre d'un tick : ballon (intégration, filet) → joueurs (mouvement, actions, contacts)
## → sol (atterrissage, relance).

const DRILL_START := Vector2(-6.0, 1.0)

var params: ParamStore
var rng: MatchRng
var dt: float
var tick_count := 0
var ball := BallBody.new()
var court: CourtGeometry
var actors: Array[PlayerActor] = []

## Paramètres structurels figés (appliqués au prochain rallye ; en J2 : au prochain lancer).
var _rally_params: Dictionary = {}
var _ctx := SimContext.new()


## `lineup` : personnages des joueurs (J2 : un seul est pris en compte, placé côté gauche, tourné vers le filet).
func _init(param_store: ParamStore, seed_value: int, tick_dt: float, lineup: Array[CharacterDefinition] = []) -> void:
	params = param_store
	rng = MatchRng.new(seed_value)
	dt = tick_dt
	court = CourtGeometry.from_params(params)
	if lineup.size() > 1:
		GameLog.warning("Match", "J2 : un seul joueur est géré, %d ignoré(s)" % (lineup.size() - 1))
	if not lineup.is_empty():
		actors.append(PlayerActor.new(0, lineup[0], params.get_value(ParamIds.PLAYER_START_X), 1))
	_ctx.params = params
	_ctx.rng = rng
	_ctx.ball = ball
	_ctx.court = court
	_ctx.dt = dt
	_freeze_rally_params()
	_launch_drill_ball()


## Un pas de simulation. `intents[i]` = intention du joueur i (absente = immobile).
## Renvoie les événements produits depuis le pas précédent (le premier appel inclut ceux de
## l'initialisation, datés du tick 0).
func tick(intents: Array[PlayerIntent] = []) -> Array[MatchEvent]:
	tick_count += 1
	_ctx.tick = tick_count
	var ball_from := ball.position
	ball.step(dt, params.get_value(ParamIds.BALL_GRAVITY), params.get_value(ParamIds.AIR_DRAG))
	_collide_net(ball_from)
	for i in actors.size():
		var intent: PlayerIntent = intents[i] if i < intents.size() else PlayerIntent.make()
		actors[i].tick(intent, _ctx, ball_from)
	if ball.position.y <= ball.radius and ball.velocity.y < 0.0:
		_ctx.emit(MatchEvent.Type.BALL_LANDED, {"x": snappedf(ball.position.x, 0.001)})
		_freeze_rally_params()
		_launch_drill_ball()
	return _ctx.take_events()


func state() -> MatchState:
	var s := MatchState.new()
	s.tick = tick_count
	s.seed_value = rng.master_seed
	s.ball_position = ball.position
	s.ball_velocity = ball.velocity
	s.ball_radius = ball.radius
	s.court_half_length = court.half_length
	s.net_height = court.net_height
	s.net_half_thickness = court.net_half_thickness
	for actor in actors:
		s.players.append(actor.snapshot(params))
	return s


## Place le ballon (scénarios de test, exercices). Ne produit pas d'événement.
func place_ball(position: Vector2, velocity: Vector2) -> void:
	ball.position = position
	ball.velocity = velocity


func _collide_net(ball_from: Vector2) -> void:
	var hit := SweptCollision.circle_vs_box(ball_from, ball.position, ball.radius, court.net_box())
	if hit == null:
		return
	var speed_before := ball.velocity.length()
	ball.position = hit.center + hit.normal * SweptCollision.SKIN
	ball.velocity = SweptCollision.reflect(ball.velocity, hit.normal, params.get_value(ParamIds.NET_RESTITUTION))
	_ctx.emit(MatchEvent.Type.NET_HIT, {
		"x": snappedf(hit.center.x, 0.001), "y": snappedf(hit.center.y, 0.001),
		"nx": hit.normal.x, "ny": hit.normal.y, "speed": snappedf(speed_before, 0.001)})


func _freeze_rally_params() -> void:
	var before := _rally_params.duplicate()
	_rally_params = {ParamIds.BALL_RADIUS: params.get_value(ParamIds.BALL_RADIUS)}
	ball.radius = _rally_params[ParamIds.BALL_RADIUS]
	if not before.is_empty() and before != _rally_params:
		_ctx.emit(MatchEvent.Type.PARAMS_APPLIED, {"ball_radius": ball.radius})


func _launch_drill_ball() -> void:
	var speed := rng.range_tagged(MatchRng.STREAM_MISC, "drill_speed",
		params.get_value(ParamIds.DRILL_SPEED_MIN), params.get_value(ParamIds.DRILL_SPEED_MAX))
	var angle := rng.range_tagged(MatchRng.STREAM_MISC, "drill_angle",
		params.get_value(ParamIds.DRILL_ANGLE_MIN), params.get_value(ParamIds.DRILL_ANGLE_MAX))
	ball.position = DRILL_START
	ball.velocity = Vector2(cos(angle), sin(angle)) * speed
	_ctx.emit(MatchEvent.Type.BALL_LAUNCHED, {"speed": snappedf(speed, 0.001), "angle": snappedf(angle, 0.0001)})
