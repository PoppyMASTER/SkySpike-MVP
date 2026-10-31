extends TestCase
## Match 3v3 complet, six personnages pilotés par l'IA : déroulement, règles, absence de blocage.

const SEEDS := [1, 2, 3]

static var _cache := {}


func _play(seed_value: int) -> Dictionary:
	if not _cache.has(seed_value):
		_cache[seed_value] = AiMatch.play(SimHelpers.data(), seed_value, AiMatch.MAX_TICKS, true)
	return _cache[seed_value]


func test_full_ai_matches_finish_with_a_legal_score() -> void:
	for s: int in SEEDS:
		var r := _play(s)
		assert_true(r.finished, "graine %d : le match se termine (%d ticks)" % [s, r.ticks])
		var sc: Array = r.score
		var hi := maxi(sc[0], sc[1])
		var lo := mini(sc[0], sc[1])
		assert_true(hi >= 15 and hi - lo >= 2, "graine %d : score légal %s" % [s, sc])
		assert_eq(r.winner, 0 if sc[0] > sc[1] else 1, "graine %d : vainqueur cohérent" % s)
		assert_true(r.counts.points == sc[0] + sc[1], "graine %d : un point par rallye" % s)


func test_ai_matches_are_reproducible() -> void:
	var a := _play(3)
	var b := AiMatch.play(SimHelpers.data(), 3, AiMatch.MAX_TICKS, true)
	assert_eq(a.fingerprint, b.fingerprint, "même graine : même état final")
	assert_eq(a.events.hash(), b.events.hash(), "même graine : même journal")
	assert_true(_play(2).events.hash() != a.events.hash(), "autre graine : autre match")


func test_all_six_characters_take_part_and_blocks_happen() -> void:
	var by_slot := {}
	var blocks := 0
	var serves := 0
	for s: int in SEEDS:
		for line in _play(s).events.split("\n"):
			if line.contains("CONTACT") and line.contains(" slot="):
				var slot := int(line.split("slot=")[1].split(" ")[0])
				by_slot[slot] = int(by_slot.get(slot, 0)) + 1
				if line.contains("action=serve"):
					serves += 1
			elif line.contains("BLOCK_RESOLVED"):
				blocks += 1
	for slot in 6:
		assert_true(int(by_slot.get(slot, 0)) > 0, "le joueur %d touche le ballon" % slot)
	assert_true(serves > 20, "des services sont frappés (%d)" % serves)
	assert_true(blocks > 0, "au moins un contre résolu sur %d matchs" % SEEDS.size())


func test_rallies_are_not_trivial_and_phases_follow_the_cycle() -> void:
	var r := _play(2)
	assert_true(float(r.counts.contacts) / maxi(1, r.counts.points) > 2.0, "plus de 2 contacts par point en moyenne")
	var phases: Array[String] = []
	for line in r.events.split("\n"):
		if line.contains("PHASE_CHANGED"):
			phases.append(line.split("phase=")[1].split(" ")[0])
	var next := {"READY": "SERVE_PREP", "SERVE_PREP": "BALL_LIVE", "BALL_LIVE": "POINT_AWARDED",
		"POINT_AWARDED": "RESET", "RESET": "READY"}
	for i in range(1, phases.size()):
		if phases[i - 1] == "POINT_AWARDED" and phases[i] == "MATCH_OVER":
			continue
		assert_eq(phases[i], next[phases[i - 1]], "transition %d : %s → %s" % [i, phases[i - 1], phases[i]])
	assert_eq(phases[phases.size() - 1], "MATCH_OVER", "dernière phase")
