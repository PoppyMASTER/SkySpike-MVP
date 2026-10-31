extends TestCase
## Clips JSON : chargement, validation, repli, interpolation, limites anatomiques des poses livrées.

const DIR := "user://test_clips"
const DATA_ROOT := "res://data"


func _issues() -> Array[LoadIssue]:
	return []


func _clip_json(id: String, extra := {}) -> Dictionary:
	var d := {"schema_version": 1, "id": id, "action": "idle", "duration_s": 1.0, "loop": false,
		"keyframes": [{"t": 0.0, "pose": {"torso": 0.0}}, {"t": 1.0, "pose": {"torso": 1.0}}]}
	d.merge(extra, true)
	return d


func _load(id: String, extra := {}, issues: Array[LoadIssue] = []) -> AnimationClip:
	var path := DIR.path_join(id + ".json")
	write_json(path, _clip_json(id, extra))
	return AnimationClip.from_file(path, issues)


func test_all_shipped_clips_load_without_any_issue() -> void:
	var lib := ClipLibrary.new()
	lib.load_all(DATA_ROOT)
	assert_eq(lib.issues.size(), 0, "aucun problème de chargement : %s" % [lib.issues.map(func(i: LoadIssue) -> String: return i.describe())])
	assert_true(lib.clips.size() >= 11, "au moins 11 clips livrés")
	for action in AnimationSetDefinition.ACTIONS:
		assert_true(lib.standard_actions.has(action), "clip standard pour « %s »" % action)
		var clip := lib.clip_for(null, action)
		assert_eq(clip.action, action, "clip « %s » prévu pour son action" % clip.id)


func test_interpolation_between_keyframes_and_clamping() -> void:
	var clip := _load("lin", {"default_interpolation": "linear"})
	assert_near(clip.sample(0.5).torso, 0.5, 1e-6, "milieu = moyenne")
	assert_near(clip.sample(-1.0).torso, 0.0, 1e-6, "avant le début : première pose")
	assert_near(clip.sample(9.0).torso, 1.0, 1e-6, "après la fin : dernière pose")
	var smooth := _load("smooth", {"default_interpolation": "smooth"})
	assert_near(smooth.sample(0.25).torso, 0.15625, 1e-5, "lissage (smoothstep)")


func test_spline_keeps_speed_through_keys_and_never_overshoots() -> void:
	var keys := [{"t": 0.0, "pose": {"torso": 0.0}}, {"t": 0.5, "pose": {"torso": 1.0}}, {"t": 1.0, "pose": {"torso": 2.0}},
		{"t": 1.5, "pose": {"torso": 1.5}}]
	var clip := _load("spl", {"default_interpolation": "spline", "duration_s": 1.5, "keyframes": keys})
	for k in 4:
		assert_near(clip.sample(float(keys[k].t)).torso, float(keys[k].pose.torso), 1e-5, "passe par la pose %d" % k)
	var speed: float = (clip.sample(0.51).torso - clip.sample(0.49).torso) / 0.02
	assert_true(speed > 1.5, "même sens : la vitesse est conservée en traversant la pose (%.2f/s)" % speed)
	var stop: float = absf(clip.sample(1.01).torso - clip.sample(0.99).torso) / 0.02
	assert_true(stop < 0.1, "changement de sens : arrêt sur la pose (%.2f/s)" % stop)
	for k in 31:
		var v: float = clip.sample(1.5 * k / 30.0).torso
		assert_true(v >= -1e-5 and v <= 2.0 + 1e-5, "jamais de dépassement (%.3f)" % v)
	var wrap := _load("wrap", {"default_interpolation": "spline", "keyframes": [{"t": 0.0, "pose": {"torso": 2.8}},
		{"t": 0.5, "pose": {"torso": -3.0}}, {"t": 1.0, "pose": {"torso": -2.6}}]})
	assert_true(absf(wrap.sample(0.25).torso) > 2.8, "angles déroulés : passe par ±π, pas par 0 (%.3f)" % wrap.sample(0.25).torso)


func test_loop_wraps_and_returns_to_the_first_pose() -> void:
	var clip := _load("loop", {"loop": true, "default_interpolation": "linear",
		"keyframes": [{"t": 0.0, "pose": {"torso": 0.0}}, {"t": 0.5, "pose": {"torso": 1.0}}]})
	assert_near(clip.sample(0.75).torso, 0.5, 1e-6, "retour vers la première pose")
	assert_near(clip.sample(1.25).torso, 0.5, 1e-6, "le temps se replie sur la durée")


func test_invalid_data_is_reported_and_repaired() -> void:
	var issues := _issues()
	var clip := _load("bad", {"keyframes": [
		{"t": 0.0, "pose": {"torso": 0.2, "tail": 1.0, "head": 9.0}},
		{"t": 0.5, "pose": {"torso": 0.4}},
		{"t": 0.4, "pose": {"torso": 0.9}}], "time_domain": "teleport", "pose_mode": "relative"}, issues)
	assert_true(clip != null, "le clip reste utilisable")
	assert_eq(clip.poses.size(), 2, "pose à temps non croissant ignorée")
	assert_false(clip.poses[0].has("tail"), "os inconnu ignoré")
	assert_false(clip.poses[0].has("head"), "angle absurde remplacé par le repos")
	assert_eq(clip.time_domain, "seconds", "domaine inconnu → seconds")
	var text := "\n".join(issues.map(func(i: LoadIssue) -> String: return i.describe()))
	for expected in ["tail", "head", "teleport", "relative", "non croissant"]:
		assert_true(text.contains(expected), "problème signalé : " + expected)


func test_unusable_files_are_rejected() -> void:
	var issues := _issues()
	write_json(DIR.path_join("broken.json"), "{ pas du json")
	assert_true(AnimationClip.from_file(DIR.path_join("broken.json"), issues) == null, "JSON invalide")
	assert_true(AnimationClip.from_file(DIR.path_join("absent.json"), issues) == null, "fichier absent")
	assert_true(_load("nokeys", {"keyframes": []}, issues) == null, "aucune pose clé")
	write_json(DIR.path_join("wrong_id.json"), _clip_json("autre"))
	assert_true(AnimationClip.from_file(DIR.path_join("wrong_id.json"), issues) == null, "id ≠ nom de fichier")
	var wrong_version := _clip_json("v9")
	wrong_version["schema_version"] = 9
	write_json(DIR.path_join("v9.json"), wrong_version)
	assert_true(AnimationClip.from_file(DIR.path_join("v9.json"), issues) == null, "version inconnue")
	assert_true(issues.size() >= 5, "chaque rejet est signalé")


func test_window_clip_without_impact_marker_gets_a_default() -> void:
	var issues := _issues()
	var clip := _load("win", {"time_domain": "window"}, issues)
	assert_near(clip.marker("impact", -1.0), 0.4, 1e-6, "repère d'impact par défaut = 40 % de la durée")
	assert_true(issues.size() > 0, "avertissement")


func test_fallback_chain_for_missing_clips() -> void:
	var lib := ClipLibrary.new()
	lib.load_all(DATA_ROOT)
	var set := AnimationSetDefinition.new()
	set.overrides = {"spike": "n_existe_pas"}
	assert_eq(lib.clip_for(set, "spike").id, "spike_v1", "remplacement introuvable → clip standard")
	assert_eq(lib.clip_for(set, "plongeon").id, "rest_plongeon", "action inconnue → pose de repos")
	assert_eq(lib.clip_for(null, "idle").id, "idle_v1", "sans ensemble : standard")
	var hammer := SimHelpers.data().characters.get_character("hammer_01")
	assert_eq(lib.clip_for(hammer.animation_set, "spike").id, "hammer_spike_v1", "le smash marteau remplace le smash standard")
	assert_eq(lib.clip_for(hammer.animation_set, "run").id, "run_v1", "les autres animations restent standard")
	var issues := _issues()
	var fake := CharacterDefinition.new()
	fake.id = "fake"
	fake.animation_set = AnimationSetDefinition.new()
	fake.animation_set.overrides = {"spike": "n_existe_pas", "set": "idle_v1"}
	lib.validate_overrides(fake, issues)
	assert_eq(issues.size(), 2, "remplacement inconnu (erreur) et clip d'une autre action (avertissement)")
	var ok_issues := _issues()
	lib.validate_overrides(hammer, ok_issues)
	assert_eq(ok_issues.size(), 0, "le remplacement livré est valide")


func test_shipped_poses_respect_human_joint_limits() -> void:
	var lib := ClipLibrary.new()
	lib.load_all(DATA_ROOT)
	for id in lib.clip_ids():
		var clip := lib.get_clip(id)
		for i in clip.poses.size():
			var pose: Dictionary = clip.poses[i]
			for side in ["l", "r"]:
				assert_true(float(pose.get("forearm_" + side, 0.0)) <= 0.05, "%s[%d] : coude %s sans hyper-extension" % [id, i, side])
				assert_true(float(pose.get("shin_" + side, 0.0)) >= -0.05, "%s[%d] : genou %s sans hyper-extension" % [id, i, side])
				assert_true(float(pose.get("shin_" + side, 0.0)) <= 2.5, "%s[%d] : genou %s plié au plus 143°" % [id, i, side])
				assert_true(float(pose.get("thigh_" + side, 0.0)) >= -2.0 and float(pose.get("thigh_" + side, 0.0)) <= 0.9, "%s[%d] : hanche %s dans sa plage" % [id, i, side])
			assert_true(absf(float(pose.get("neck", 0.0))) <= 0.6 and absf(float(pose.get("head", 0.0))) <= 0.6, "%s[%d] : cou et tête" % [id, i])


func test_grounded_poses_rest_on_the_ground_without_extreme_drops() -> void:
	var lib := ClipLibrary.new()
	lib.load_all(DATA_ROOT)
	var character := SimHelpers.data().characters.get_character("std_attacker_01")
	var animator := RigAnimator.new(lib, character)
	for id in lib.clip_ids():
		var clip := lib.get_clip(id)
		if not clip.grounded:
			continue
		for step in 21:
			var f := animator.evaluate_clip(clip, clip.duration_s * float(step) / 20.0, true)
			var global := RigDef.forward_kinematics(f.pose, animator.offsets)
			var sole := RigDef.lowest_sole(global, animator.dims) + f.shift_y
			assert_near(sole, 0.0, 1e-4, "%s : semelles au sol (pas %d)" % [id, step])
			assert_true(absf(f.shift_y) < 0.45, "%s : décalage vertical plausible (%.2f m, pas %d)" % [id, f.shift_y, step])
	remove_dir(DIR)
