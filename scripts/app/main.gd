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


## Outil de vérification : `-- --capture DOSSIER` enregistre deux captures (match seul,
## puis panneau sandbox ouvert via F1) et quitte. Utilisé pour les rapports de jalon.
func _handle_capture_args() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--capture")
	if i < 0 or i + 1 >= args.size():
		return
	var dir := args[i + 1]
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("j1_match.png"))
	var f1 := InputEventKey.new()
	f1.physical_keycode = KEY_F1
	f1.pressed = true
	Input.parse_input_event(f1)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("j1_sandbox.png"))
	get_tree().quit()
