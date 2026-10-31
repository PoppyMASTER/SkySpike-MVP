extends TestCase
## Squelette commun : hiérarchie, proportions, rigidité (pas d'étirement), morphologie visuelle.

func _dims(height := 1.0, weight := 1.0, arm_span := 1.0, leg_length := 1.0) -> RigDims:
	var m := MorphologyDefinition.new()
	m.height = height
	m.weight = weight
	m.arm_span = arm_span
	m.leg_length = leg_length
	return RigDef.dims_for(m)


func test_rig_has_17_bones_with_a_valid_hierarchy() -> void:
	assert_eq(RigDef.BONES.size(), 17, "17 os")
	assert_eq(RigDef.BONES[0], "root", "la racine vient en premier")
	for bone in RigDef.BONES:
		if bone == "root":
			continue
		var parent: String = RigDef.PARENTS.get(bone, "")
		assert_true(RigDef.BONES.has(parent), "%s : parent %s existe" % [bone, parent])
		assert_true(RigDef.BONES.find(parent) < RigDef.BONES.find(bone), "%s : parent déclaré avant l'enfant" % bone)
	for needed in ["pelvis", "torso", "neck", "head", "upper_arm_l", "upper_arm_r", "forearm_l", "forearm_r",
			"hand_l", "hand_r", "thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r"]:
		assert_true(RigDef.is_bone(needed), "os " + needed)


func test_standard_proportions_are_natural() -> void:
	var d := _dims()
	assert_near(d.standing_height(), 1.8, 0.02, "1,80 m debout")
	assert_near(d.leg_total() / d.standing_height(), 0.53, 0.03, "jambes ≈ 53 % de la taille")
	assert_near((d.upper_arm + d.forearm + d.hand) / d.standing_height(), 0.36, 0.03, "bras ≈ 36 % de la taille")
	assert_true(d.upper_arm > d.forearm and d.forearm > d.hand, "bras > avant-bras > main")
	assert_true(d.thigh > d.shin, "cuisse plus longue que la jambe inférieure")


func test_rest_pose_stands_on_the_ground() -> void:
	var d := _dims()
	var global := RigDef.forward_kinematics({}, RigDef.rest_offsets(d))
	assert_near(RigDef.lowest_sole(global, d), 0.0, 1e-5, "semelles au sol au repos")
	var head_y: float = (global["head"] as Transform2D).origin.y
	assert_true(head_y < (global["torso"] as Transform2D).origin.y, "tête au-dessus du torse (y vers le bas)")


func test_limbs_never_stretch_whatever_the_pose() -> void:
	var d := _dims(1.1, 1.0, 1.1, 1.05)
	var offsets := RigDef.rest_offsets(d)
	var rng := RandomNumberGenerator.new()   # hasard du TEST (poses arbitraires)
	rng.seed = 5
	for trial in 20:
		var pose := {}
		for bone in RigDef.BONES:
			pose[bone] = rng.randf_range(-2.5, 2.5)
		var global := RigDef.forward_kinematics(pose, offsets)
		for bone in RigDef.BONES:
			var parent: String = RigDef.PARENTS.get(bone, "")
			if parent == "":
				continue
			var gap: float = ((global[bone] as Transform2D).origin - (global[parent] as Transform2D).origin).length()
			var expected: float = (offsets[bone] as Vector2).length()
			assert_near(gap, expected, 1e-4, "%s : longueur conservée" % bone)


func test_morphology_changes_only_the_drawing_dimensions() -> void:
	var standard := _dims()
	var tall := _dims(1.15)
	assert_near(tall.standing_height() / standard.standing_height(), 1.15, 0.01, "taille ×1,15")
	var long_legs := _dims(1.0, 1.0, 1.0, 1.1)
	assert_near(long_legs.thigh / standard.thigh, 1.1, 1e-5, "jambes ×1,1")
	assert_near(long_legs.torso, standard.torso, 1e-6, "le torse ne bouge pas")
	var wingspan := _dims(1.0, 1.0, 1.1, 1.0)
	assert_near(wingspan.upper_arm / standard.upper_arm, 1.1, 1e-5, "envergure ×1,1")
	assert_near(wingspan.thigh, standard.thigh, 1e-6, "les jambes ne bougent pas")
	assert_true(_dims(1.0, 1.15).thickness > 1.0, "corpulence : pièces plus épaisses")
	assert_eq(RigDef.dims_for(null).standing_height(), standard.standing_height(), "sans morphologie : gabarit standard")


func test_simulation_and_gameplay_never_read_morphology() -> void:
	for layer in ["simulation", "gameplay", "ai", "input"]:
		for path in ArchitectureScan.script_files("res://scripts/" + layer):
			var text := FileAccess.get_file_as_string(path)
			assert_false(text.contains("morphology") or text.contains("MorphologyDefinition"), "%s ne lit pas la morphologie" % path)
