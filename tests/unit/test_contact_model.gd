extends TestCase
## Modèle de contact : qualité, vitesse et angle de sortie.


func test_quality_is_one_at_the_ideal_and_decreases_with_each_error() -> void:
	assert_eq(ContactModel.quality(0.0, 0.0, 0.5, 0.5), 1.0, "parfait")
	assert_near(ContactModel.quality(1.0, 0.0, 0.5, 0.5), 0.5, 1e-9, "erreur de temps 1")
	assert_near(ContactModel.quality(0.0, 1.0, 0.5, 0.5), 0.5, 1e-9, "erreur d'espace 1")
	assert_near(ContactModel.quality(1.0, 1.0, 0.5, 0.5), 0.0, 1e-9, "les deux")
	assert_eq(ContactModel.quality(3.0, 3.0, 0.5, 0.5), 0.0, "borné à 0")
	assert_eq(ContactModel.quality(0.0, 0.0, 2.0, 2.0), 1.0, "borné à 1")


func test_quality_is_symmetric_for_early_and_late() -> void:
	assert_near(ContactModel.quality(-0.6, 0.2, 0.5, 0.5), ContactModel.quality(0.6, 0.2, 0.5, 0.5), 1e-12, "trop tôt = trop tard")


func test_time_and_space_errors() -> void:
	assert_near(ContactModel.time_error(0.05, 0.14, 0.12), -0.75, 1e-9, "trop tôt = négatif")
	assert_near(ContactModel.time_error(0.2, 0.14, 0.12), 0.5, 1e-9, "trop tard = positif")
	assert_near(ContactModel.space_error(0.3, 0.6), 0.5, 1e-9, "moitié du rayon")
	assert_true(is_finite(ContactModel.time_error(1.0, 0.0, 0.0)), "tolérance nulle : pas de division par zéro")


func test_speed_interpolates_between_floor_and_top() -> void:
	assert_near(ContactModel.speed(10.0, 1.0, 0.5), 10.0, 1e-9, "qualité 1")
	assert_near(ContactModel.speed(10.0, 0.0, 0.5), 5.0, 1e-9, "qualité 0")
	assert_near(ContactModel.speed(10.0, 0.5, 0.5), 7.5, 1e-9, "qualité 0,5")


func test_early_is_higher_late_is_lower_forward_aim_is_flatter() -> void:
	var ideal := ContactModel.exit_angle(1.0, 0.0, 0.35, 0.0, 0.35, 0.0)
	var early := ContactModel.exit_angle(1.0, -1.0, 0.35, 0.0, 0.35, 0.0)
	var late := ContactModel.exit_angle(1.0, 1.0, 0.35, 0.0, 0.35, 0.0)
	assert_true(early > ideal and ideal > late, "trop tôt > idéal > trop tard")
	var forward := ContactModel.exit_angle(1.0, 0.0, 0.35, 1.0, 0.35, 0.0)
	var backward := ContactModel.exit_angle(1.0, 0.0, 0.35, -1.0, 0.35, 0.0)
	assert_true(forward < ideal and ideal < backward, "avant = plus tendu, arrière = plus haut")
	assert_near(ContactModel.exit_angle(1.0, -50.0, 0.35, 0.0, 0.35, 0.0), ContactModel.ANGLE_LIMIT, 1e-12, "angle borné en haut")
	assert_near(ContactModel.exit_angle(-1.0, 50.0, 0.35, 0.0, 0.35, 0.0), -ContactModel.ANGLE_LIMIT, 1e-12, "angle borné en bas")


func test_exit_velocity_follows_facing() -> void:
	var right := ContactModel.exit_velocity(10.0, 0.5, 1)
	var left := ContactModel.exit_velocity(10.0, 0.5, -1)
	assert_true(right.x > 0.0 and left.x < 0.0, "sens horizontal selon le regard")
	assert_near(right.y, left.y, 1e-12, "même hauteur")
	assert_near(right.length(), 10.0, 1e-9, "norme = vitesse demandée")
