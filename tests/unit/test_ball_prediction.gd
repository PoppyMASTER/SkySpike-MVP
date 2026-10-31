extends TestCase
## Prévision de la trajectoire du ballon (affichée en permanence en transparence).

const G := 10.0


func test_landing_matches_the_closed_form() -> void:
	var pred := BallPrediction.compute(Vector2(-6.0, 2.0), Vector2(8.0, 5.0), 0.105, G, 2.43, 9.0)
	assert_true(pred != null, "ballon en vol")
	var t := Ballistics.time_to_height(2.0, 5.0, G, 0.105)
	assert_near(pred.landing_x, -6.0 + 8.0 * t, 1e-4, "x d'atterrissage")
	assert_near(pred.path[pred.path.size() - 1].y, 0.105, 1e-4, "la trajectoire finit au sol")
	assert_true(pred.lands_inside and not pred.hits_net, "dans les lignes, sans filet")


func test_ball_into_the_net_stops_at_the_net() -> void:
	var pred := BallPrediction.compute(Vector2(-3.0, 1.0), Vector2(6.0, 1.0), 0.105, G, 2.43, 9.0)
	assert_true(pred != null and pred.hits_net, "tir bas : arrêté par le filet")
	assert_near(pred.path[pred.path.size() - 1].x, 0.0, 1e-4, "la prévision s'arrête au filet")
	assert_false(pred.lands_inside, "ne retombe pas dans le terrain")


func test_out_and_resting_ball() -> void:
	var out_pred := BallPrediction.compute(Vector2(2.0, 3.0), Vector2(9.0, 2.0), 0.105, G, 2.43, 9.0)
	assert_true(out_pred != null and not out_pred.lands_inside, "retombe dehors")
	assert_true(BallPrediction.compute(Vector2(1.0, 0.105), Vector2.ZERO, 0.105, G, 2.43, 9.0) == null, "ballon posé : aucune prévision")
