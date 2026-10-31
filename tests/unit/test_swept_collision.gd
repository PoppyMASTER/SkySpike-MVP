extends TestCase
## Collisions balayées : le trajet entier est testé, pas seulement la position d'arrivée.

const NET := Rect2(-0.05, 0.0, 0.1, 2.43)
const R := 0.105


func test_head_on_hit_on_the_net_face() -> void:
	var hit := SweptCollision.circle_vs_box(Vector2(-1, 1), Vector2(1, 1), R, NET)
	assert_true(hit != null, "contact détecté")
	assert_eq(hit.normal, Vector2(-1, 0), "normale vers la gauche (côté d'où vient le ballon)")
	assert_near(hit.t, (1.0 - 0.05 - R) / 2.0, 1e-6, "fraction du trajet avant le contact")
	assert_near(hit.center.x, -0.05 - R, 1e-6, "le ballon s'arrête au contact, pas dans le filet")


func test_fast_ball_cannot_tunnel_through_a_thin_net() -> void:
	# Départ et arrivée sont tous deux hors du filet : un test de position finale le raterait.
	var from := Vector2(-0.3, 1.0)
	var to := Vector2(0.3, 1.0)
	var end_only := Vector2(clampf(to.x, NET.position.x, NET.end.x), clampf(to.y, NET.position.y, NET.end.y))
	assert_true(to.distance_to(end_only) > R, "la position finale seule ne montre aucun recouvrement")
	var hit := SweptCollision.circle_vs_box(from, to, R, NET)
	assert_true(hit != null, "le balayage détecte la traversée")


func test_no_net_crossing_for_thousands_of_random_fast_shots() -> void:
	var rng := RandomNumberGenerator.new()   # hasard du TEST uniquement
	rng.seed = 1234
	var dt := 1.0 / 120.0
	var missed := 0
	for i in 5000:
		var from := Vector2(rng.randf_range(-3.0, -0.2), rng.randf_range(0.2, 2.2))
		var speed := rng.randf_range(5.0, 80.0)
		var angle := rng.randf_range(-0.6, 0.6)
		var to := from + Vector2(cos(angle), sin(angle)) * speed * dt
		if from.x < -R - 0.05 and to.x > R + 0.05 and minf(from.y, to.y) > 0.1 and maxf(from.y, to.y) < 2.3:
			if SweptCollision.circle_vs_box(from, to, R, NET) == null:
				missed += 1
	assert_eq(missed, 0, "aucune traversée non détectée")


func test_top_edge_hit_from_above() -> void:
	var hit := SweptCollision.circle_vs_box(Vector2(0, 3.0), Vector2(0, 2.0), R, NET)
	assert_true(hit != null, "contact avec le bord supérieur")
	assert_eq(hit.normal, Vector2(0, 1), "normale vers le haut")
	assert_near(hit.center.y, 2.43 + R, 1e-6, "le ballon repose sur le bord")


func test_passing_clearly_over_the_net_is_not_a_hit() -> void:
	assert_true(SweptCollision.circle_vs_box(Vector2(-1, 3.0), Vector2(1, 3.0), R, NET) == null, "passe au-dessus")
	assert_true(SweptCollision.circle_vs_box(Vector2(-1, 2.43 + 0.2), Vector2(1, 2.43 + 0.2), R, NET) == null, "frôle le bord sans le toucher")


func test_corner_hit_has_a_diagonal_normal_and_stays_at_radius_distance() -> void:
	var corner := Vector2(-0.05, 2.43)
	var from := Vector2(-0.4, 2.75)
	var to := Vector2(0.0, 2.45)
	var hit := SweptCollision.circle_vs_box(from, to, R, NET)
	assert_true(hit != null, "contact avec le coin")
	if hit == null:
		return
	assert_true(hit.normal.x < 0.0 and hit.normal.y > 0.0, "normale diagonale vers le haut et la gauche : %s" % hit.normal)
	assert_near(hit.center.distance_to(corner), R, 1e-6, "centre à un rayon du coin")


func test_ball_moving_away_from_an_overlap_is_not_blocked() -> void:
	assert_true(SweptCollision.circle_vs_box(Vector2(-0.1, 1.0), Vector2(-0.5, 1.0), R, NET) == null, "s'éloigne")


func test_ball_already_overlapping_and_moving_in_is_pushed_out_at_t0() -> void:
	var hit := SweptCollision.circle_vs_box(Vector2(-0.1, 1.0), Vector2(0.2, 1.0), R, NET)
	assert_true(hit != null, "contact")
	assert_eq(hit.t, 0.0, "t = 0")
	assert_eq(hit.normal, Vector2(-1, 0), "repoussé vers la gauche")


func test_reflect_keeps_tangent_and_scales_normal() -> void:
	var v := SweptCollision.reflect(Vector2(10, 2), Vector2(-1, 0), 0.35)
	assert_near(v.x, -3.5, 1e-9, "composante normale inversée × 0,35")
	assert_near(v.y, 2.0, 1e-9, "composante tangente conservée")
	assert_eq(SweptCollision.reflect(Vector2(-4, 1), Vector2(-1, 0), 0.5), Vector2(-4, 1), "déjà en éloignement : inchangé")


func test_point_segment_distance() -> void:
	assert_near(SweptCollision.point_segment_distance(Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)), 1.0, 1e-9, "au milieu")
	assert_near(SweptCollision.point_segment_distance(Vector2(3, 0), Vector2(-1, 0), Vector2(1, 0)), 2.0, 1e-9, "au-delà de l'extrémité")
	assert_near(SweptCollision.point_segment_distance(Vector2(1, 1), Vector2(0, 0), Vector2(0, 0)), sqrt(2.0), 1e-6, "segment réduit à un point")
