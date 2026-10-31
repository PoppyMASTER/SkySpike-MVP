extends TestCase
## MatchRng : même graine = mêmes tirages ; flux indépendants ; tirages étiquetés.


func _sequence(rng: MatchRng, stream: StringName, n: int) -> Array[float]:
	var out: Array[float] = []
	for i in n:
		out.append(rng.randf_tagged(stream, "t"))
	return out


func test_same_seed_gives_same_sequence() -> void:
	assert_eq(_sequence(MatchRng.new(42), MatchRng.STREAM_CONTACTS, 20),
		_sequence(MatchRng.new(42), MatchRng.STREAM_CONTACTS, 20), "séquences identiques")


func test_different_seeds_differ() -> void:
	assert_true(_sequence(MatchRng.new(1), MatchRng.STREAM_CONTACTS, 5) != _sequence(MatchRng.new(2), MatchRng.STREAM_CONTACTS, 5),
		"graines différentes → séquences différentes")


func test_streams_are_independent() -> void:
	var a := MatchRng.new(7)
	var b := MatchRng.new(7)
	_sequence(b, MatchRng.STREAM_AI, 50)   # l'IA tire beaucoup dans b
	assert_eq(_sequence(a, MatchRng.STREAM_CONTACTS, 10), _sequence(b, MatchRng.STREAM_CONTACTS, 10),
		"les tirages de l'IA ne décalent pas ceux des contacts")


func test_derived_seeds_are_stable_across_runs() -> void:
	# Valeur relevée au J1 avec Godot 4.7.2. Si elle change (nouvelle version de Godot),
	# les scénarios enregistrés ne sont plus rejouables : à signaler, pas à corriger en silence.
	assert_eq(MatchRng.derive_seed(42, "contacts"), DERIVED_42_CONTACTS, "dérivation de graine stable")


func test_trace_records_tagged_draws() -> void:
	var rng := MatchRng.new(3)
	rng.trace_enabled = true
	rng.gaussian_tagged(MatchRng.STREAM_CONTACTS, "spike_angle_noise", 0.1)
	rng.range_tagged(MatchRng.STREAM_MISC, "drill_speed", 1.0, 2.0)
	assert_eq(rng.trace.size(), 2, "deux tirages journalisés")
	assert_eq(rng.trace[0].tag, "spike_angle_noise", "étiquette conservée")
	var v: float = rng.trace[1].value
	assert_true(v >= 1.0 and v <= 2.0, "valeur dans l'intervalle")


const DERIVED_42_CONTACTS := 1806303452
