extends TestCase
## Chargement des personnages : données réelles, puis chaque règle de repli sur des fichiers de test.

const ROOT := "user://test_characters"


func test_real_characters_load_without_error() -> void:
	var repo := CharacterRepository.new()
	repo.load_all()
	assert_eq(repo.error_count(), 0, "aucune erreur : %s" % [repo.issues.map(func(i: LoadIssue) -> String: return i.describe())])
	assert_eq(repo.ids().size(), 6, "six personnages d'exemple")


func test_hammer_has_spike_override_and_morphology() -> void:
	var repo := CharacterRepository.new()
	repo.load_all()
	var hammer := repo.get_character("hammer_01")
	assert_true(hammer != null, "hammer_01 chargé")
	assert_eq(hammer.animation_set.clip_for("spike"), "hammer_spike_v1", "remplacement du smash")
	assert_false(hammer.animation_set.has_override("receive"), "pas de remplacement de la réception")
	assert_eq(hammer.morphology.weight, 1.10, "corpulence lue")
	assert_eq(hammer.stats.attack_power, 75, "stat lue")


func test_standard_character_uses_defaults() -> void:
	var repo := CharacterRepository.new()
	repo.load_all()
	var c := repo.get_character("std_defender_01")
	assert_true(c.morphology.is_standard(), "morphologie standard")
	assert_eq(c.animation_set.default_set, AnimationSetDefinition.STANDARD_SET, "jeu d'animations standard")
	assert_true(c.animation_set.overrides.is_empty(), "aucun remplacement")


# ------------------------------------------------------------------ replis
func _base(id: String, extra := {}) -> Dictionary:
	var d := {"schema_version": 1, "id": id, "display_name": "Test", "role": "attacker",
		"stats_ref": "characters/stats/%s.json" % id}
	d.merge(extra, true)
	return d


func _templates() -> void:
	for role: String in ["attacker", "setter", "defender"]:
		write_json(ROOT + "/characters/stats/_role_%s.json" % role, {"schema_version": 1, "attack_power": 60,
			"receive": 61, "block": 62, "set_power": 63, "set_accuracy": 64, "spike_accuracy": 65, "speed": 66, "jump": 67})


func _load() -> CharacterRepository:
	var repo := CharacterRepository.new(ROOT)
	repo.load_all()
	return repo


func _messages(repo: CharacterRepository) -> String:
	return " | ".join(repo.issues.map(func(i: LoadIssue) -> String: return i.describe()))


func test_invalid_json_rejects_character_with_message() -> void:
	remove_dir(ROOT)
	_templates()
	write_json(ROOT + "/characters/broken.json", "{ \"id\": ")
	var repo := _load()
	assert_eq(repo.ids().size(), 0, "personnage rejeté")
	assert_true(_messages(repo).contains("JSON invalide"), "message lisible : " + _messages(repo))
	remove_dir(ROOT)


func test_missing_and_invalid_stats_use_role_template() -> void:
	remove_dir(ROOT)
	_templates()
	write_json(ROOT + "/characters/partial.json", _base("partial"))
	write_json(ROOT + "/characters/stats/partial.json", {"schema_version": 1, "attack_power": 80, "receive": 150, "speed": "vite"})
	var repo := _load()
	var c := repo.get_character("partial")
	assert_true(c != null, "personnage gardé")
	assert_eq(c.stats.attack_power, 80, "stat valide lue")
	assert_eq(c.stats.receive, 61, "stat hors bornes → gabarit")
	assert_eq(c.stats.speed, 66, "stat de mauvais type → gabarit")
	assert_eq(c.stats.jump, 67, "stat manquante → gabarit")
	assert_true(_messages(repo).contains("receive"), "erreur signalée sur receive")
	remove_dir(ROOT)


func test_missing_stats_file_uses_whole_template() -> void:
	remove_dir(ROOT)
	_templates()
	write_json(ROOT + "/characters/nostats.json", _base("nostats"))
	var repo := _load()
	var c := repo.get_character("nostats")
	assert_eq(c.stats.block, 62, "gabarit entier")
	assert_true(_messages(repo).contains("introuvable"), "fichier introuvable signalé")
	remove_dir(ROOT)


func test_unknown_version_and_role_and_id_mismatch_are_rejected() -> void:
	remove_dir(ROOT)
	_templates()
	write_json(ROOT + "/characters/future.json", _base("future", {"schema_version": 2}))
	write_json(ROOT + "/characters/norole.json", _base("norole", {"role": "libero"}))
	write_json(ROOT + "/characters/wrongname.json", _base("autre_id"))
	var repo := _load()
	assert_eq(repo.ids().size(), 0, "les trois sont rejetés")
	var msg := _messages(repo)
	assert_true(msg.contains("version 2"), "version signalée")
	assert_true(msg.contains("libero"), "rôle inconnu signalé")
	assert_true(msg.contains("nom du fichier"), "id ≠ nom du fichier signalé")
	remove_dir(ROOT)


func test_morphology_and_animation_fallbacks() -> void:
	remove_dir(ROOT)
	_templates()
	write_json(ROOT + "/characters/fb.json", _base("fb", {"morphology_ref": "morphology/absent.json",
		"animation_set_ref": "animations/fb.json", "couleur": "rouge"}))
	write_json(ROOT + "/characters/stats/fb.json", {"schema_version": 1})
	write_json(ROOT + "/animations/fb.json", {"schema_version": 1, "overrides": {"spike": "mon_smash", "danse": "x"}})
	var repo := _load()
	var c := repo.get_character("fb")
	assert_true(c.morphology.is_standard(), "morphologie absente → standard")
	assert_eq(c.animation_set.clip_for("spike"), "mon_smash", "remplacement valide gardé")
	assert_false(c.animation_set.has_override("danse"), "action inconnue ignorée")
	var msg := _messages(repo)
	assert_true(msg.contains("danse"), "action inconnue signalée")
	assert_true(msg.contains("couleur"), "champ inconnu signalé")
	remove_dir(ROOT)


func test_extreme_morphology_is_accepted_with_warning() -> void:
	remove_dir(ROOT)
	_templates()
	write_json(ROOT + "/characters/big.json", _base("big", {"morphology_ref": "morphology/big.json"}))
	write_json(ROOT + "/characters/stats/big.json", {"schema_version": 1})
	write_json(ROOT + "/morphology/big.json", {"schema_version": 1, "height": 1.4, "weight": 3.0})
	var repo := _load()
	var c := repo.get_character("big")
	assert_eq(c.morphology.height, 1.4, "valeur expérimentale acceptée")
	assert_eq(c.morphology.weight, 1.0, "valeur hors bornes expérimentales → 1.0")
	assert_true(_messages(repo).contains("plage normale"), "avertissement de plage")
	remove_dir(ROOT)
