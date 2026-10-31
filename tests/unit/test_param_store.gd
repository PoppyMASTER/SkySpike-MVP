extends TestCase
## ParamStore : bornes, mode expérimental, réinitialisation, application de valeurs.


func _store() -> ParamStore:
	var a := ParamDef.new()
	a.id = &"alpha"
	a.default_value = 10.0
	a.min_value = 0.0
	a.max_value = 20.0
	a.experimental_min = -50.0
	a.experimental_max = 100.0
	var b := ParamDef.new()
	b.id = &"count"
	b.default_value = 3.0
	b.min_value = 1.0
	b.max_value = 8.0
	b.experimental_min = 1.0
	b.experimental_max = 64.0
	b.is_integer = true
	var defs: Array[ParamDef] = [a, b]
	return ParamStore.new(defs)


func test_defaults_are_loaded() -> void:
	var s := _store()
	assert_eq(s.get_value(&"alpha"), 10.0, "valeur par défaut")
	assert_eq(s.ids().size(), 2, "nombre de paramètres")


func test_value_in_range_is_accepted() -> void:
	var s := _store()
	assert_eq(s.set_value(&"alpha", 15.0), ParamStore.SetResult.ACCEPTED, "15 dans [0, 20]")
	assert_eq(s.get_value(&"alpha"), 15.0, "valeur modifiée")


func test_value_out_of_range_is_rejected_outside_experimental_mode() -> void:
	var s := _store()
	assert_eq(s.set_value(&"alpha", 30.0), ParamStore.SetResult.REJECTED_OUT_OF_RANGE, "30 hors bornes")
	assert_eq(s.get_value(&"alpha"), 10.0, "valeur inchangée après refus")


func test_experimental_mode_allows_wider_range_only() -> void:
	var s := _store()
	s.experimental_mode = true
	assert_eq(s.set_value(&"alpha", 30.0), ParamStore.SetResult.ACCEPTED, "30 accepté en mode expérimental")
	assert_true(s.is_outside_normal(&"alpha"), "signalé hors bornes normales")
	assert_eq(s.set_value(&"alpha", 500.0), ParamStore.SetResult.REJECTED_OUT_OF_RANGE, "500 refusé même en expérimental")


func test_integer_params_are_rounded() -> void:
	var s := _store()
	s.set_value(&"count", 4.6)
	assert_eq(s.get_value(&"count"), 5.0, "arrondi à l'entier")


func test_unknown_param_is_reported_not_crashing() -> void:
	var s := _store()
	assert_eq(s.set_value(&"nope", 1.0), ParamStore.SetResult.UNKNOWN_PARAM, "paramètre inconnu")
	assert_eq(s.get_value(&"nope"), 0.0, "lecture d'un inconnu = 0")
	assert_eq(GameLog.count(GameLog.Level.ERROR), 2, "deux erreurs journalisées")


func test_reset_restores_default() -> void:
	var s := _store()
	s.set_value(&"alpha", 2.0)
	s.reset_all()
	assert_eq(s.get_value(&"alpha"), 10.0, "défaut rétabli")


func test_apply_values_reports_problems() -> void:
	var s := _store()
	var issues := s.apply_values({&"alpha": 5.0, &"count": 99.0, &"ghost": 1.0}, false)
	assert_eq(s.get_value(&"alpha"), 5.0, "valeur valide appliquée")
	assert_eq(s.get_value(&"count"), 3.0, "valeur hors bornes ignorée")
	assert_eq(issues.size(), 2, "deux problèmes signalés")


func test_snapshot_is_a_copy() -> void:
	var s := _store()
	var snap := s.snapshot()
	s.set_value(&"alpha", 1.0)
	assert_eq(snap[&"alpha"], 10.0, "la copie ne suit pas les modifications")
