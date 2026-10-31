class_name ServiceCapture
extends RefCounted
## Outil de vérification des animations de service : `-- --capture-service DOSSIER`.
## Joue trois services scriptés (sol, flottant, smash) avec le VRAI simulateur, relève les instants clés, puis rejoue
## le même service (déterministe) en photographiant des vignettes autour du serveur : 12 images par service,
## en vue normale et en vue squelette + pivots, et une démonstration des transitions (smash).
## Les vignettes sont assemblées en planches par `tools/service_sheets.py`.

## Scénarios : [ticks de maintien de L, tick du saut (Espace) ou -1, tick de la frappe (L)], comptés après le lancer.
const SCRIPTS := {"sol": [0, -1, 18], "flottant": [0, 40, 42], "smash": [150, 12, 30]}
const SEED := 1
const CROP_M := Vector2(3.6, 4.4)   # largeur, hauteur (m) de la vignette autour du serveur
const BASE_Y_M := -0.35


## Joue le scénario sans photographier et note les ticks clés.
static func scan(runner: MatchRunner, script: Array) -> Dictionary:
	runner.human_slot = 0
	runner.restart(SEED)
	var marks := {}
	var server := runner.sim.ctx.rally.server_slot
	var step := func(intent: PlayerIntent) -> void:
		var intents := runner.ai.intents(runner.current_state)
		intents[server] = intent
		runner.run_one_tick(intents)
		var actor: PlayerActor = runner.sim.actors[server]
		var tick := runner.current_state.tick
		if actor.state == Enums.ActionState.SERVE_JUMP and not marks.has("jump"):
			marks["jump"] = tick
		if actor.state == Enums.ActionState.SERVE_HIT and not marks.has("open"):
			marks["open"] = tick
		if actor.state != Enums.ActionState.SERVE_HIT and marks.has("open") and not marks.has("end"):
			marks["end"] = tick
		if actor.state == Enums.ActionState.RECOVER and marks.has("end") and not marks.has("land"):
			marks["land"] = tick
	while runner.sim.actors[server].state != Enums.ActionState.SERVE_HOLD:
		step.call(PlayerIntent.make())
	marks["hold"] = runner.current_state.tick
	step.call(PlayerIntent.make(0, false, false, false, false, true, true))
	marks["press"] = runner.current_state.tick
	for i in script[0]:
		step.call(PlayerIntent.make(0, false, false, false, false, false, true))
	step.call(PlayerIntent.make())
	marks["release"] = runner.current_state.tick
	marks["script_start"] = runner.current_state.tick
	for i in 220:
		var it := PlayerIntent.make(0.0, i == script[1])
		if i == script[2]:
			it = PlayerIntent.make(0, false, false, false, false, true, true)
		step.call(it)
	return marks


## Liste de vignettes [nom, tick] pour un service : 12 images réparties sur les phases du geste.
static func frame_plan(kind: String, marks: Dictionary) -> Array:
	var r: int = marks.release
	var o: int = marks.open
	var e: int = marks.end
	var j: int = marks.get("jump", -1)
	var plan: Array = [
		["01 attente avec ballon", marks.hold + 2],
		["02 préparation (charge)", maxi(marks.press + 1, r - 2)],
		["03 lancer", r + 3],
		["04 ballon monte", r + 12],
	]
	if kind == "sol":
		plan += [["05 transfert de poids", o - 6], ["06 armement", o], ["07 avant l'impact", e - 3]]
	else:
		plan += [["05 placement et élan", j - 5], ["06 impulsion (compression)", j + 1], ["07 extension", j + 10]]
		plan += [["08 armement", o]]
	plan += [["09 impact", e], ["10 suivi du geste", e + 6], ["11 suivi (fin)", e + 16]]
	plan += [["12 atterrissage", marks.get("land", e + 30) + 6]]
	if kind == "sol":
		plan.insert(7, ["08 frappe", e - 7])
	return plan


## Photographie une liste de vignettes en rejouant le service.
static func shoot(host: Node, runner: MatchRunner, script: Array, plan: Array, dir: String, prefix: String, debug: bool) -> void:
	runner.human_slot = 0
	runner.restart(SEED)
	runner.set_paused(true)
	runner.view.show_skeleton = debug
	runner.view.show_pivots = debug
	runner.view.show_zones = false
	runner.data.params.set_value(ParamIds.PREVIEW_VISIBLE, 0.0)
	runner.data.params.set_value(ParamIds.FX_ENABLED, 0.0)
	await host.get_tree().process_frame
	var server := runner.sim.ctx.rally.server_slot
	var wanted := {}
	for item: Array in plan:
		var t := int(item[1])
		while wanted.has(t):
			t -= 1  # deux vignettes sur le même tick : la seconde recule d'un tick (service très compact)
		wanted[t] = item[0]
	var step := func(intent: PlayerIntent) -> void:
		var intents := runner.ai.intents(runner.current_state)
		intents[server] = intent
		runner.run_one_tick(intents)
	while runner.sim.actors[server].state != Enums.ActionState.SERVE_HOLD:
		step.call(PlayerIntent.make())
		await _maybe(host, runner, server, wanted, dir, prefix)
	step.call(PlayerIntent.make(0, false, false, false, false, true, true))
	await _maybe(host, runner, server, wanted, dir, prefix)
	for i in script[0]:
		step.call(PlayerIntent.make(0, false, false, false, false, false, true))
		await _maybe(host, runner, server, wanted, dir, prefix)
	step.call(PlayerIntent.make())
	await _maybe(host, runner, server, wanted, dir, prefix)
	for i in 220:
		var it := PlayerIntent.make(0.0, i == script[1])
		if i == script[2]:
			it = PlayerIntent.make(0, false, false, false, false, true, true)
		step.call(it)
		await _maybe(host, runner, server, wanted, dir, prefix)


static func _maybe(host: Node, runner: MatchRunner, server: int, wanted: Dictionary, dir: String, prefix: String) -> void:
	var tick := runner.current_state.tick
	if not wanted.has(tick):
		return
	runner.view.show_states(runner.previous_state, runner.current_state, 1.0)
	await RenderingServer.frame_post_draw
	var image := host.get_viewport().get_texture().get_image()
	var k := runner.view.pixels_per_meter()
	var center := runner.view.to_screen(Vector2(runner.current_state.players[server].position.x, 0.0))
	var size := Vector2i(roundi(CROP_M.x * k), roundi(CROP_M.y * k))
	var origin := Vector2i(roundi(center.x - size.x * 0.5), roundi(center.y - (CROP_M.y + BASE_Y_M) * k))
	origin = Vector2i(clampi(origin.x, 0, image.get_width() - size.x), clampi(origin.y, 0, image.get_height() - size.y))
	var crop := image.get_region(Rect2i(origin, size))
	crop.save_png(dir.path_join("%s_%s.png" % [prefix, String(wanted[tick]).replace(" ", "_").replace("'", "").replace("/", "-")]))
