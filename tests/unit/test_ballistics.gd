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


func test_parabola_through_net_top_and_target() -> void:
	var from := Vector2(-9.15, 2.1)
	var via := Vector2(0.0, 2.73)
	var target := Vector2(5.0, 0.105)
	var sol := Ballistics.through_two_points(from, via, target, 10.0)
	assert_false(is_nan(sol.angle), "trois points en cloche : solution")
	var ball := BallBody.new()
	ball.position = from
	ball.velocity = Vector2(cos(sol.angle), sin(sol.angle)) * sol.speed
	var top_y := -INF
	for i in 2000:
		var before := ball.position
		ball.step(1.0 / 240.0, 10.0, 0.0)
		if before.x < 0.0 and ball.position.x >= 0.0:
			top_y = ball.position.y
		if ball.position.y <= target.y:
			assert_near(ball.position.x, target.x, 0.05, "retombe sur la cible")
			break
	assert_near(top_y, via.y, 0.05, "passe par le dessus du filet")


func test_parabola_rejects_impossible_points_and_speed_for_angle_matches() -> void:
	assert_true(is_nan(Ballistics.through_two_points(Vector2(-9, 2), Vector2(0, 2.7), Vector2(-4, 0.1), 10.0).angle), "cible avant le filet : pas de solution")
	var speed := Ballistics.speed_for_angle(Vector2(-9.15, 2.1), 0.5, Vector2(5.0, 0.105), 10.0)
	var ball := BallBody.new()
	ball.position = Vector2(-9.15, 2.1)
	ball.velocity = Vector2(cos(0.5), sin(0.5)) * speed
	for i in 2000:
		ball.step(1.0 / 240.0, 10.0, 0.0)
		if ball.position.y <= 0.105:
			break
	assert_near(ball.position.x, 5.0, 0.05, "vitesse calculée : atteint la cible")
	assert_true(is_nan(Ballistics.speed_for_angle(Vector2(0, 5), 0.0, Vector2(5, 6), 10.0)), "cible plus haute en tir plat : impossible")
