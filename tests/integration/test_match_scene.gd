extends TestCase
## La scène de match s'instancie, charge les données et avance sans erreur.

const MATCH_SCENE := "res://scenes/match/match.tscn"


func test_match_scene_runs_ticks_without_errors() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var runner: MatchRunner = (load(MATCH_SCENE) as PackedScene).instantiate()
	runner.data = GameData.load_default()
	tree.root.add_child(runner)
	# Pendant _initialize, la racine n'est pas encore « prête » : _ready n'est pas appelé,
	# on démarre donc le match explicitement.
	runner.restart(1)
	for i in 600:
		runner.run_one_tick()
	assert_eq(runner.current_state.tick, 600, "600 ticks exécutés")
	assert_eq(GameLog.count(GameLog.Level.ERROR), 0, "aucune erreur journalisée : %s" % [GameLog.entries])
	assert_true(runner.event_log.size() > 0, "événements reçus par le runner")
	runner.restart(5)
	assert_eq(runner.current_state.tick, 0, "relance remet le tick à 0")
	assert_eq(runner.current_state.seed_value, 5, "nouvelle graine prise en compte")
	runner.queue_free()


func test_keyboard_input_moves_the_player_through_the_runner() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var runner: MatchRunner = (load(MATCH_SCENE) as PackedScene).instantiate()
	runner.data = GameData.load_default()
	tree.root.add_child(runner)
	InputMapper.register_actions()
	runner.restart(1)
	var start_x := runner.current_state.players[0].position.x
	Input.action_press(InputMapper.MOVE_RIGHT)
	for i in 30:
		InputMapper.poll(runner.input)
		runner.run_one_tick()
	Input.action_release(InputMapper.MOVE_RIGHT)
	assert_true(runner.current_state.players[0].position.x > start_x + 0.5, "le joueur avance quand → est tenue")
	runner.queue_free()
