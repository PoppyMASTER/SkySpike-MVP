extends TestCase
## Presets livrés (default, legacy_reference) et presets utilisateur.

const USER_DIR := "user://test_presets"


func _store() -> PresetStore:
	remove_dir(USER_DIR)
	var store := PresetStore.new()
	store.load_all(PresetStore.BUILTIN_DIR, USER_DIR)
	return store


func test_builtin_presets_load_cleanly() -> void:
	var store := _store()
	assert_eq(store.issues.size(), 0, "aucun problème : %s" % [store.issues.map(func(i: LoadIssue) -> String: return i.describe())])
	assert_true(store.presets.has("default"), "preset default présent")
	assert_true(store.presets.has("legacy_reference"), "preset legacy_reference présent")


func test_legacy_reference_applies_without_issue() -> void:
	var store := _store()
	var params := real_params()
	var problems := params.apply_values(store.resolve("legacy_reference"), store.is_experimental("legacy_reference"))
	assert_eq(problems.size(), 0, "toutes les valeurs historiques sont connues et dans les bornes : %s" % [problems])
	assert_eq(params.get_value(ParamIds.BALL_GRAVITY), 11.0, "gravité historique")
	assert_eq(params.get_value(ParamIds.SIM_HZ), 120.0, "valeur non redéfinie : défaut conservé")


func test_user_preset_roundtrip() -> void:
	var store := _store()
	var params := real_params()
	params.set_value(ParamIds.BALL_GRAVITY, 12.5)
	var preset := params.to_preset("mon_test")
	assert_eq(store.save_user(preset, USER_DIR), OK, "enregistrement")
	var reloaded := PresetStore.new()
	reloaded.load_all(PresetStore.BUILTIN_DIR, USER_DIR)
	assert_true(reloaded.presets.has("mon_test"), "rechargé depuis le disque")
	var fresh := real_params()
	fresh.apply_values(reloaded.resolve("mon_test"), false)
	assert_eq(fresh.get_value(ParamIds.BALL_GRAVITY), 12.5, "valeur restituée")
	remove_dir(USER_DIR)


func test_builtin_preset_cannot_be_overwritten() -> void:
	var store := _store()
	var preset := ParamPreset.new()
	preset.id = "default"
	assert_eq(store.save_user(preset, USER_DIR), ERR_ALREADY_EXISTS, "refus d'écraser un preset livré")
	remove_dir(USER_DIR)


func test_invalid_user_preset_is_reported() -> void:
	remove_dir(USER_DIR)
	write_json(USER_DIR + "/casse.json", "{ pas du json")
	write_json(USER_DIR + "/autre_nom.json", {"schema_version": 1, "id": "pas_pareil", "values": {}})
	var store := PresetStore.new()
	store.load_all(PresetStore.BUILTIN_DIR, USER_DIR)
	assert_eq(store.issues.size(), 2, "JSON invalide et id différent du nom de fichier")
	assert_false(store.presets.has("pas_pareil"), "preset rejeté")
	remove_dir(USER_DIR)
