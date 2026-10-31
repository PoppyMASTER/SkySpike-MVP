class_name MatchSim
extends RefCounted
## Seul système autoritaire de la simulation. Avance d'un pas fixe à chaque appel de tick().
## N'utilise ni temps réel, ni durée d'image, ni hasard hors MatchRng.
##
## Avec six joueurs (trois par équipe : slots 0-2 à gauche, 3-5 à droite), le match est complet :
## phases READY → SERVE_PREP → BALL_LIVE → POINT_AWARDED → RESET, arbitre, score. Avec moins de
## joueurs, c'est le « mode libre » (tests, bac à sable) : ballon en jeu, aucune règle.
##
## Ordre d'un tick : phases → ballon (intégration, filet) → joueurs (mouvement, actions, contacts)
## → arbitre (contacts, atterrissage).

var params: ParamStore
var rng: MatchRng
var dt: float
var tick_count := 0
var ball := BallBody.new()
var court: CourtGeometry
var actors: Array[PlayerActor] = []
var ctx := SimContext.new()
var referee: Referee

## Mode match complet (six joueurs).
var _flow := false
var _ball_frozen := false
var _ready_hold := 0.0


## `lineup` : personnages dans l'ordre des slots. `human_slot` : joueur piloté par le clavier (-1 = aucun).
func _init(param_store: ParamStore, seed_value: int, tick_dt: float, lineup: Array[CharacterDefinition] = [], human_slot := -1) -> void:
	params = param_store
	rng = MatchRng.new(seed_value)
	dt = tick_dt
	court = CourtGeometry.from_params(params)
	ctx.params = params
	ctx.rng = rng
	ctx.ball = ball
	ctx.court = court
	ctx.dt = dt
	ctx.human_slot = human_slot
	ctx.actors = actors
	referee = Referee.new(ctx)
	_flow = lineup.size() == 6
	for i in lineup.size():
		var team := i / 3
		actors.append(PlayerActor.new(i, team, lineup[i], 0.0, 1 if team == 0 else -1))
	ball.radius = params.get_value(ParamIds.BALL_RADIUS)
	if _flow:
		referee.initial_service(0)
		_place_for_service()
		referee.set_phase(Enums.Phase.READY)
	else:
		for actor in actors:
			actor.reset_to(params.get_value(ParamIds.PLAYER_START_X))
		ctx.rally.phase = Enums.Phase.BALL_LIVE
	ctx.take_events()   # les événements d'initialisation ne sont pas diffusés


## Un pas de simulation. `intents[i]` = intention du joueur i (absente = immobile).
func tick(intents: Array[PlayerIntent] = []) -> Array[MatchEvent]:
	tick_count += 1
	ctx.tick = tick_count
	var rally := ctx.rally
	rally.phase_time += dt
	if _flow:
		_advance_phase()
	var ball_from := ball.position
	if ctx.ball_held:
		var server := actors[rally.server_slot]
		ball.position = server.serve_hold_position(params)
		ball.velocity = Vector2.ZERO
		ball_from = ball.position
	elif not _ball_frozen:
		ball.step(dt, params.get_value(ParamIds.BALL_GRAVITY), params.get_value(ParamIds.AIR_DRAG))
		_collide_net(ball_from)
	for i in actors.size():
		var intent: PlayerIntent = intents[i] if i < intents.size() else PlayerIntent.make()
		actors[i].tick(intent, ctx, ball_from)
	_judge()
	return ctx.take_events()


func state() -> MatchState:
	var s := MatchState.new()
	s.tick = tick_count
	s.tick_seconds = dt
	s.seed_value = rng.master_seed
	s.ball_position = ball.position
	s.ball_velocity = ball.velocity
	s.ball_radius = ball.radius
	s.ball_held = ctx.ball_held
	s.court_half_length = court.half_length
	s.net_height = court.net_height
	s.net_half_thickness = court.net_half_thickness
	for actor in actors:
		s.players.append(actor.snapshot(params))
	var r := ctx.rally
	s.phase = r.phase
	s.phase_time = r.phase_time
	s.score = r.score.duplicate()
	s.serving_team = r.serving_team
	s.server_slot = r.server_slot
	s.touches = r.touches.duplicate()
	s.last_team = r.last_team
	s.last_slot = r.last_slot
	s.last_was_block = r.last_was_block
	s.contact_seq = r.contact_seq
	s.served = r.served
	s.winner = r.winner
	s.point_winner = r.point_winner
	s.fault_text = r.fault_text
	s.human_slot = ctx.human_slot
	if not ctx.ball_held and not _ball_frozen:
		s.ball_prediction = BallPrediction.compute(ball.position, ball.velocity, ball.radius,
			params.get_value(ParamIds.BALL_GRAVITY), court.net_height, court.half_length)
	if _flow and ctx.human_slot == r.server_slot and not r.served:
		s.serve_preview = ServePreview.compute(actors[r.server_slot], ctx)
	return s


## Place le ballon (scénarios de test, exercices). Ne produit pas d'événement.
func place_ball(position: Vector2, velocity: Vector2) -> void:
	ball.position = position
	ball.velocity = velocity
	_ball_frozen = false


# ------------------------------------------------------------------ phases
func _advance_phase() -> void:
	var rally := ctx.rally
	match rally.phase:
		Enums.Phase.READY:
			if rally.phase_time >= params.get_value(ParamIds.READY_S):
				referee.set_phase(Enums.Phase.SERVE_PREP)
				for actor in actors:
					if actor.slot == rally.server_slot:
						actor.begin_serve()
		Enums.Phase.SERVE_PREP:
			if actors[rally.server_slot].state == Enums.ActionState.SERVE_TOSS:
				referee.set_phase(Enums.Phase.BALL_LIVE)
				for actor in actors:
					actor.unlock()
		Enums.Phase.POINT_AWARDED:
			if rally.phase_time >= params.get_value(ParamIds.POINT_S):
				if rally.winner >= 0:
					referee.set_phase(Enums.Phase.MATCH_OVER)
					ctx.emit(MatchEvent.Type.MATCH_WON, {"winner": rally.winner,
						"score_0": rally.score[0], "score_1": rally.score[1]})
				else:
					referee.prepare_next_service()
					_place_for_service(false)
					referee.set_phase(Enums.Phase.RESET)
		Enums.Phase.RESET:
			if rally.phase_time >= params.get_value(ParamIds.RESET_S) and _everyone_home():
				referee.set_phase(Enums.Phase.READY)


## Verrouille tout le monde à son poste et remet le ballon dans la main du serveur.
## `teleport` : placement immédiat (début de match) ; sinon les joueurs marchent jusqu'à leur poste.
func _place_for_service(teleport := true) -> void:
	for actor in actors:
		var x := _home_x(actor)
		if teleport:
			actor.reset_to(x)
		actor.lock_to(x)
	_ball_frozen = false
	ctx.ball_held = true


func _home_x(actor: PlayerActor) -> float:
	if actor.slot == ctx.rally.server_slot:
		return -actor.facing * (court.half_length + params.get_value(ParamIds.SERVE_START_OFFSET))
	var id := ParamIds.HOME_ATTACKER_X
	if actor.character.role == Enums.Role.SETTER:
		id = ParamIds.HOME_SETTER_X
	elif actor.character.role == Enums.Role.DEFENDER:
		id = ParamIds.HOME_DEFENDER_X
	return -actor.facing * params.get_value(id)


func _everyone_home() -> bool:
	for actor in actors:
		if not actor.body.grounded or absf(actor.body.position.x - _home_x(actor)) > 1e-6:
			return false
	return true


# ------------------------------------------------------------------ arbitre
func _judge() -> void:
	var contacts := ctx.contacts
	ctx.contacts = []
	if not _flow:
		_rest_ball_if_landed()
		return
	if ctx.rally.phase != Enums.Phase.BALL_LIVE:
		return
	for contact in contacts:
		if referee.register_contact(contact):
			_ball_frozen = true
			return
	if ball.position.y <= ball.radius and ball.velocity.y < 0.0:
		ball.position.y = ball.radius
		ball.velocity = Vector2.ZERO
		_ball_frozen = true
		referee.landing(ball.position.x)


## Mode libre : le ballon s'arrête au sol (pas de relance automatique).
func _rest_ball_if_landed() -> void:
	if not _ball_frozen and ball.position.y <= ball.radius and ball.velocity.y < 0.0:
		ctx.emit(MatchEvent.Type.BALL_LANDED, {"x": snappedf(ball.position.x, 0.001)})
		ball.position.y = ball.radius
		ball.velocity = Vector2.ZERO
		_ball_frozen = true


func _collide_net(ball_from: Vector2) -> void:
	var hit := SweptCollision.circle_vs_box(ball_from, ball.position, ball.radius, court.net_box())
	if hit == null:
		return
	var speed_before := ball.velocity.length()
	ball.position = hit.center + hit.normal * SweptCollision.SKIN
	ball.velocity = SweptCollision.reflect(ball.velocity, hit.normal, params.get_value(ParamIds.NET_RESTITUTION))
	ctx.emit(MatchEvent.Type.NET_HIT, {
		"x": snappedf(hit.center.x, 0.001), "y": snappedf(hit.center.y, 0.001),
		"nx": hit.normal.x, "ny": hit.normal.y, "speed": snappedf(speed_before, 0.001)})
