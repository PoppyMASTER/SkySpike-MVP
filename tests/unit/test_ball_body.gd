extends TestCase
## BallBody : trajectoire balistique exacte sans frottement, ralentissement avec frottement.


func test_free_flight_matches_analytic_trajectory() -> void:
	var ball := BallBody.new()
	var v0 := Vector2(5.0, 8.0)
	ball.velocity = v0
	var g := 10.0
	var dt := 1.0 / 120.0
	for i in 120:
		ball.step(dt, g, 0.0)
	var expected := Vector2(v0.x * 1.0, v0.y * 1.0 - 0.5 * g * 1.0)
	assert_near(ball.position.x, expected.x, 1e-3, "x après 1 s")
	assert_near(ball.position.y, expected.y, 1e-3, "y après 1 s")
	assert_near(ball.velocity.y, v0.y - g, 1e-3, "vy après 1 s")


func test_result_does_not_depend_on_step_size_without_drag() -> void:
	var a := BallBody.new()
	var b := BallBody.new()
	a.velocity = Vector2(3, 9)
	b.velocity = Vector2(3, 9)
	for i in 60:
		a.step(1.0 / 60.0, 10.0, 0.0)
	for i in 240:
		b.step(1.0 / 240.0, 10.0, 0.0)
	assert_near(a.position.y, b.position.y, 1e-3, "même position à 60 et 240 pas/s")


func test_drag_slows_the_ball() -> void:
	var free := BallBody.new()
	var dragged := BallBody.new()
	free.velocity = Vector2(10, 0)
	dragged.velocity = Vector2(10, 0)
	for i in 120:
		free.step(1.0 / 120.0, 0.0, 0.0)
		dragged.step(1.0 / 120.0, 0.0, 0.3)
	assert_true(dragged.position.x < free.position.x, "le frottement raccourcit la trajectoire")
