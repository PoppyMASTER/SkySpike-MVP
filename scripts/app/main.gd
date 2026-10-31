extends Node
## Point d'entrée : charge les données, liste les personnages dans la console, puis ouvre la scène
## de test du match. L'écran de sélection (poste, perso, visée) viendra avec les menus ; en attendant,
## le joueur contrôlé se choisit dans le panneau F1.

const MATCH_SCENE := preload("res://scenes/match/match.tscn")


func _ready() -> void:
	var data := GameData.load_default()
	for id: String in data.characters.ids():
		GameLog.info("Personnage", data.characters.get_character(id).describe())
	var match_runner: MatchRunner = MATCH_SCENE.instantiate()
	match_runner.data = data
	add_child(match_runner)
	_handle_sim_args(data)
	_handle_capture_args()


## `-- --sim N` : N matchs IA contre IA sans affichage (graines 1..N), résumé en console, puis quitte.
func _handle_sim_args(data: GameData) -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--sim")
	if i < 0 or i + 1 >= args.size():
		return
	var total := {"contacts": 0, "points": 0, "blocks": 0, "net_hits": 0, "out": 0}
	for seed_value in int(args[i + 1]):
		var r := AiMatch.play(data, seed_value + 1)
		for key: String in total:
			total[key] += r.counts[key]
		print("graine %d : %s en %.0f s %s" % [seed_value + 1, r.score, r.ticks / 120.0, r.counts])
	print("TOTAL %s, %.2f contacts par point" % [total, float(total.contacts) / maxf(1.0, total.points)])
	get_tree().quit()


## Outil de vérification : `-- --capture DOSSIER` joue un match IA contre IA (graine 2) sans pilote humain
## et enregistre des captures : mise en place, premier échange, passe, contre, tableau de score. Zones affichées.
func _handle_capture_args() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--capture")
	if i < 0 or i + 1 >= args.size():
		return
	var dir := args[i + 1]
	DirAccess.make_dir_recursive_absolute(dir)
	var runner: MatchRunner = get_child(get_child_count() - 1)
	runner.human_slot = -1
	runner.restart(2)
	runner.set_paused(true)
	runner.view.show_zones = true
	await get_tree().process_frame
	await _shot(runner, dir.path_join("j3_01_mise_en_place.png"))
	var wanted := ["serve", "receive", "set", "spike"]
	var next := 0
	var blocked := false
	var guard := 0
	while guard < 120 * 120 and (next < wanted.size() or not blocked):
		guard += 1
		runner.run_one_tick()
		for e in runner.event_log.slice(maxi(0, runner.event_log.size() - 3)):
			if e.tick != runner.current_state.tick:
				continue
			if e.type == MatchEvent.Type.CONTACT and next < wanted.size() and e.details.action == wanted[next]:
				await _shot(runner, dir.path_join("j3_%02d_%s.png" % [next + 2, wanted[next]]))
				next += 1
			elif e.type == MatchEvent.Type.BLOCK_RESOLVED and not blocked:
				blocked = true
				await _shot(runner, dir.path_join("j3_06_contre.png"))
	var f1 := InputEventKey.new()
	f1.physical_keycode = KEY_F1
	f1.pressed = true
	Input.parse_input_event(f1)
	await get_tree().create_timer(0.3).timeout
	await _shot(runner, dir.path_join("j3_07_panneau.png"))
	get_tree().quit()


func _shot(runner: MatchRunner, path: String) -> void:
	runner.view.show_states(runner.previous_state, runner.current_state, 1.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
