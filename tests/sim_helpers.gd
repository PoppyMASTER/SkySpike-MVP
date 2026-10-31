class_name SimHelpers
extends RefCounted
## Aides pour les tests de simulation (non incluses dans le jeu).

static var _data: GameData


static func data() -> GameData:
	if _data == null:
		_data = GameData.load_default()
	return _data


## Paramètres neufs (valeurs par défaut) pour chaque test : aucune fuite entre tests.
static func fresh_params() -> ParamStore:
	return TestCase.real_params()


static func make_sim(character_id := "std_attacker_01", seed_value := 1, tick_dt := 1.0 / 120.0, params: ParamStore = null, human_slot := -1) -> MatchSim:
	var lineup: Array[CharacterDefinition] = []
	if character_id != "":
		lineup.append(data().characters.get_character(character_id))
	return MatchSim.new(params if params != null else fresh_params(), seed_value, tick_dt, lineup, human_slot)


## Avance `count` ticks avec la même intention ; renvoie tous les événements.
static func run(sim: MatchSim, count: int, intent: PlayerIntent = null) -> Array[MatchEvent]:
	var out: Array[MatchEvent] = []
	var intents: Array[PlayerIntent] = [intent if intent != null else PlayerIntent.make()]
	for i in count:
		out.append_array(sim.tick(intents))
	return out


static func one_tick(sim: MatchSim, intent: PlayerIntent = null) -> Array[MatchEvent]:
	return run(sim, 1, intent)


static func count_type(events: Array[MatchEvent], type: int) -> int:
	var n := 0
	for e in events:
		if e.type == type:
			n += 1
	return n


static func first_of(events: Array[MatchEvent], type: int) -> MatchEvent:
	for e in events:
		if e.type == type:
			return e
	return null


## Met le ballon immobile (en l'air) au centre de la zone indiquée du joueur 0.
static func put_ball_in_zone(sim: MatchSim, receive: bool, offset := Vector2.ZERO) -> void:
	var snap := sim.actors[0].snapshot(sim.params)
	var center := snap.receive_center if receive else snap.spike_center
	sim.place_ball(center + offset, Vector2.ZERO)


## Met le ballon très loin de tout (pour que rien ne se produise).
static func park_ball(sim: MatchSim) -> void:
	sim.place_ball(Vector2(7.0, 6.0), Vector2.ZERO)
