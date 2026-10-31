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
	_handle_anim_sheet_args(data)
	_handle_capture_args()
	_handle_serve_capture_args()


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


## `-- --anim-sheet DOSSIER` : planches-contact des clips (poses clés du mannequin), puis quitte.
func _handle_anim_sheet_args(data: GameData) -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--anim-sheet")
	if i < 0 or i + 1 >= args.size():
		return
	var dir := args[i + 1]
	DirAccess.make_dir_recursive_absolute(dir)
	get_child(get_child_count() - 1).queue_free()   # pas de match derrière les planches
	var ids := data.clips.clip_ids()
	var per_sheet := 3
	for sheet in ceili(float(ids.size()) / per_sheet):
		var part: Array = []
		for k in range(sheet * per_sheet, mini(ids.size(), (sheet + 1) * per_sheet)):
			part.append(ids[k])
		var board := AnimSheet.new()
		add_child(board)
		board.build(data.clips, data.characters.get_character("std_attacker_01"), part, MatchView.COLOR_TEAM[0])
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("planche_%d.png" % (sheet + 1)))
		board.queue_free()
	get_tree().quit()


## Outil de vérification : `-- --capture DOSSIER` joue un match IA contre IA (graine 2) sans pilote humain
## et enregistre des captures : mise en place, service, réception, passe, smash, contre, debug du rig, aperçu d'animation, panneau.
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
	await _shot(runner, dir.path_join("j4_01_mise_en_place.png"))
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
				await _shot(runner, dir.path_join("j4_%02d_%s.png" % [next + 2, wanted[next]]))
				next += 1
			elif e.type == MatchEvent.Type.BLOCK_RESOLVED and not blocked:
				blocked = true
				await _shot(runner, dir.path_join("j4_06_contre.png"))
	runner.view.show_skeleton = true   # outils de debug du rig (F3, F4, F5)
	runner.view.show_pivots = true
	runner.view.show_anim_info = true
	await _shot(runner, dir.path_join("j4_07_debug_rig.png"))
	runner.view.start_preview(runner.data.clips.get_clip("hammer_spike_v1"))   # test d'une animation isolée
	runner.view.preview_time = 0.24
	runner.view.preview_playing = false
	runner.view._process(0.0)
	await _shot(runner, dir.path_join("j4_08_apercu_marteau.png"))
	var f1 := InputEventKey.new()
	f1.physical_keycode = KEY_F1
	f1.pressed = true
	Input.parse_input_event(f1)
	await get_tree().create_timer(0.3).timeout
	await _shot(runner, dir.path_join("j4_09_panneau.png"))
	get_tree().quit()


## `-- --capture-serve DOSSIER` : le joueur humain sert (graine 2) ; captures de la prévisualisation du service
## (tenue, lancer, frappe courte / moyenne / longue).
func _handle_serve_capture_args() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--capture-serve")
	if i < 0 or i + 1 >= args.size():
		return
	var dir := args[i + 1]
	DirAccess.make_dir_recursive_absolute(dir)
	var runner: MatchRunner = get_child(get_child_count() - 1)
	runner.human_slot = 0
	runner.restart(2)
	runner.set_paused(true)
	await get_tree().process_frame
	var server := runner.sim.ctx.rally.server_slot
	var step := func(axis: float, press := false) -> void:
		var intents := runner.ai.intents(runner.current_state)
		intents[server] = PlayerIntent.make(axis, false, false, false, false, press)
		runner.run_one_tick(intents)
	while runner.sim.actors[server].state != Enums.ActionState.SERVE_HOLD:
		step.call(0.0)
	var facing := runner.sim.actors[server].facing
	step.call(float(facing))
	await _shot(runner, dir.path_join("serve_01_tenue_avant.png"))
	step.call(-float(facing))
	await _shot(runner, dir.path_join("serve_02_tenue_arriere.png"))
	step.call(0.0, true)
	for t in 107:
		step.call(0.0)
	var names := ["serve_03_frappe_longue", "serve_04_frappe_neutre", "serve_05_frappe_courte"]
	var axes := [float(facing), 0.0, -float(facing)]
	for k in 3:
		step.call(axes[k])
		await _shot(runner, dir.path_join(names[k] + ".png"))
	get_tree().quit()


func _shot(runner: MatchRunner, path: String) -> void:
	runner.view.show_states(runner.previous_state, runner.current_state, 1.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
