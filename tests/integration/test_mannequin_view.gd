extends TestCase
## Mannequin Skeleton2D / Bone2D, liseré d'équipe, outils de debug (aperçu d'animation indépendant du match).

const MATCH_SCENE := "res://scenes/match/match.tscn"


func _rig(morph_character := "std_attacker_01", color := Color("4f9dde")) -> MannequinRig:
	var lib := ClipLibrary.new()
	lib.load_all("res://data")
	var animator := RigAnimator.new(lib, SimHelpers.data().characters.get_character(morph_character))
	var rig := MannequinRig.new()
	rig.build(animator.dims, color)
	return rig


func test_rig_is_a_skeleton2d_with_one_bone2d_per_rig_bone() -> void:
	var rig := _rig()
	assert_true(rig.skeleton is Skeleton2D, "Skeleton2D")
	assert_eq(rig.bones.size(), 17, "17 Bone2D")
	for bone_name: String in RigDef.PARENTS:
		var bone: Bone2D = rig.bones[bone_name]
		assert_eq(bone.get_parent(), rig.bones[RigDef.PARENTS[bone_name]], "%s : parent %s" % [bone_name, RigDef.PARENTS[bone_name]])
	assert_eq(rig.skeleton.find_children("*", "Bone2D", true, false).size(), 17, "le squelette porte ses 17 os")
	rig.queue_free()


func test_pose_rotates_bones_and_keeps_bone_lengths() -> void:
	var rig := _rig()
	var frame := AnimFrame.new()
	frame.pose = {"upper_arm_r": -1.0, "forearm_r": -0.5, "torso": 0.3}
	frame.shift_y = 0.1
	rig.apply(frame)
	assert_near((rig.bones["upper_arm_r"] as Bone2D).rotation, -1.0, 1e-6, "rotation appliquée")
	assert_near((rig.bones["head"] as Bone2D).rotation, 0.0, 1e-6, "os absent de la pose : repos")
	assert_near(rig.skeleton.position.y, 0.1, 1e-6, "décalage vertical")
	var forearm_len := rig.bone_position("hand_r").distance_to(rig.bone_position("forearm_r"))
	assert_near(forearm_len, rig.dims.forearm, 1e-4, "avant-bras non étiré")
	rig.free()


func test_team_trim_is_a_thin_outline_and_the_body_stays_anthracite() -> void:
	var blue := _rig("std_attacker_01", MatchView.COLOR_TEAM[0])
	var red := _rig("std_attacker_01", MatchView.COLOR_TEAM[1])
	var torso: Bone2D = blue.bones["torso"]
	var colors: Array[Color] = []
	for child in torso.get_children():
		if child is Polygon2D:
			colors.append((child as Polygon2D).color)
	assert_true(colors.has(MatchView.COLOR_TEAM[0]), "liseré bleu")
	assert_true(colors.has(MannequinRig.COLOR_BODY), "corps anthracite")
	assert_false(colors.has(MatchView.COLOR_TEAM[1]), "pas de rouge dans l'équipe bleue")
	var red_torso: Bone2D = red.bones["torso"]
	var red_colors: Array[Color] = []
	for child in red_torso.get_children():
		if child is Polygon2D:
			red_colors.append((child as Polygon2D).color)
	assert_true(red_colors.has(MatchView.COLOR_TEAM[1]), "liseré rouge")
	assert_true(MannequinRig.COLOR_BODY.r < 0.3 and absf(MannequinRig.COLOR_BODY.r - MannequinRig.COLOR_BODY.b) < 0.1, "gris anthracite")
	blue.free()
	red.free()


func test_morphology_changes_the_drawing_of_each_character() -> void:
	var heights := {}
	var lib := ClipLibrary.new()
	lib.load_all("res://data")
	for id: String in SimHelpers.data().characters.ids():
		heights[id] = RigAnimator.new(lib, SimHelpers.data().characters.get_character(id)).dims.standing_height()
	assert_true(heights["hammer_01"] > heights["std_attacker_01"], "le marteau est plus grand")
	assert_eq(heights.size(), 6, "six personnages")
	for id: String in heights:
		assert_true(heights[id] > 1.5 and heights[id] < 2.2, "%s : taille plausible (%.2f m)" % [id, heights[id]])


func test_view_builds_six_rigs_and_the_preview_is_independent_of_the_match() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var runner: MatchRunner = (load(MATCH_SCENE) as PackedScene).instantiate()
	runner.data = GameData.load_default()
	tree.root.add_child(runner)
	runner.human_slot = -1
	runner.view = runner.get_node("MatchView")   # _ready n'a pas encore eu lieu pendant _initialize
	runner.restart(3)
	var view := runner.view
	assert_eq(view.rigs.size(), 6, "six mannequins")
	for i in 600:
		runner.run_one_tick()
	view.show_states(runner.previous_state, runner.current_state, 0.5)
	assert_eq(view.frames.size(), 6, "six poses évaluées")
	var tick_before := runner.current_state.tick
	view.start_preview(runner.data.clips.get_clip("receive_v1"))
	view.preview_speed = 2.0
	view._process(0.1)
	assert_near(view.preview_time, 0.2, 1e-6, "l'aperçu avance avec le temps réel × sa vitesse")
	assert_true(view.preview_rig.visible, "mannequin d'aperçu affiché")
	assert_eq(runner.current_state.tick, tick_before, "la simulation n'avance pas pendant l'aperçu")
	view.preview_playing = false
	view._process(1.0)
	assert_near(view.preview_time, 0.2, 1e-6, "pause de l'aperçu")
	view.anim_speed = 2.5
	view.reset_animation_settings()
	assert_eq(view.anim_speed, 1.0, "vitesse d'animation remise à 1")
	assert_eq(view.preview_speed, 1.0, "vitesse d'aperçu remise à 1")
	assert_eq(runner.data.params.get_value(ParamIds.TIME_SCALE), 1.0, "la vitesse de simulation n'a pas bougé")
	view.stop_preview()
	assert_false(view.preview_rig.visible, "aperçu arrêté")
	runner.queue_free()
