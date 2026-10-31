extends TestCase
## Aides balistiques de l'IA et de la visée assistée.

const G := 20.0


func test_position_at_matches_projectile_formula() -> void:
	var p := Ballistics.position_at(Vector2(1, 2), Vector2(4, 6), G, 0.5)
	assert_near(p.x, 3.0, 1e-5, "x = x0 + vx·t")
	assert_near(p.y, 2.0 + 3.0 - 0.5 * G * 0.25, 1e-5, "y = y0 + vy·t − g·t²/2")


func test_time_to_height_finds_descending_crossing() -> void:
	var t := Ballistics.time_to_height(4.0, 0.0, G, 1.0)
	assert_near(t, sqrt(2.0 * 3.0 / G), 1e-5, "chute libre de 3 m")
	assert_true(Ballistics.time_to_height(1.0, 0.0, G, 5.0) < 0.0, "jamais atteint : −1")


func test_velocity_for_arrival_reaches_target() -> void:
	var from := Vector2(-6, 2)
	var to := Vector2(5, 0)
	var v := Ballistics.velocity_for_arrival(from, to, 1.2, G)
	var p := Ballistics.position_at(from, v, G, 1.2)
	assert_near(p.x, to.x, 1e-4, "arrivée en x")
	assert_near(p.y, to.y, 1e-4, "arrivée en y")


func test_angle_to_pass_hits_target_for_both_trajectories() -> void:
	var from := Vector2(-3, 2.5)
	var target := Vector2(4, 0.2)
	for high in [true, false]:
		var a := Ballistics.angle_to_pass(from, 16.0, target, G, high)
		assert_false(is_nan(a), "solution trouvée (high=%s)" % high)
		var v := Vector2(cos(a), sin(a)) * 16.0
		var t := (target.x - from.x) / v.x
		assert_near(Ballistics.position_at(from, v, G, t).y, target.y, 1e-3, "passe par la cible (high=%s)" % high)
	assert_true(is_nan(Ballistics.angle_to_pass(from, 3.0, Vector2(30, 0), G, true)), "hors de portée : NAN")
