extends Node
## Point d'entrée. J1 : charge les données, liste les personnages dans la console,
## puis ouvre la scène de test du match. L'écran de sélection (poste, perso, visée) arrive au J3.

const MATCH_SCENE := preload("res://scenes/match/match.tscn")


func _ready() -> void:
	var data := GameData.load_default()
	for id: String in data.characters.ids():
		GameLog.info("Personnage", data.characters.get_character(id).describe())
	var match_runner: MatchRunner = MATCH_SCENE.instantiate()
	match_runner.data = data
	add_child(match_runner)
	_handle_capture_args()


## Outil de vérification : `-- --capture DOSSIER` joue un scénario tick par tick (course, saut, smash,
## zones affichées), enregistre des captures (smash en cours, après contact, panneau F1) et quitte.
## Le scénario ne dépend pas de la vitesse d'affichage. Utilisé pour les rapports de jalon.
func _handle_capture_args() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--capture")
	if i < 0 or i + 1 >= args.size():
		return
	var dir := args[i + 1]
	DirAccess.make_dir_recursive_absolute(dir)
	var runner: MatchRunner = get_child(get_child_count() - 1)
	runner.set_paused(true)
	runner.view.show_zones = true
	await get_tree().process_frame
	_play(runner, 45, PlayerIntent.make(1.0))                       # course vers le filet
	_play(runner, 1, PlayerIntent.make(1.0, true))                  # saut
	_play(runner, 22, PlayerIntent.make(0.0))
	_play(runner, 1, PlayerIntent.make(0.0, true))                  # smash engagé
	var spike_zone := runner.current_state.players[0].spike_center
	runner.sim.place_ball(spike_zone + Vector2(0.1, 0.1), Vector2.ZERO)
	_play(runner, 3, PlayerIntent.make(0.0))
	await _shot(runner, dir.path_join("j2_smash_window.png"))
	_play(runner, 6, PlayerIntent.make(0.0))
	await _shot(runner, dir.path_join("j2_after_contact.png"))
	var f1 := InputEventKey.new()
	f1.physical_keycode = KEY_F1
	f1.pressed = true
	Input.parse_input_event(f1)
	await get_tree().create_timer(0.3).timeout
	await _shot(runner, dir.path_join("j2_sandbox.png"))
	get_tree().quit()


func _play(runner: MatchRunner, ticks: int, intent: PlayerIntent) -> void:
	for t in ticks:
		var intents: Array[PlayerIntent] = [intent]
		runner.run_one_tick(intents)
		intent = PlayerIntent.make(intent.move_axis)   # l'appui n'a lieu qu'au premier tick


func _shot(runner: MatchRunner, path: String) -> void:
	runner.view.show_states(runner.previous_state, runner.current_state, 1.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
