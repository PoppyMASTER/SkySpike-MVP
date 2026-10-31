extends TestCase
## PlayerBody : course, freinage, saut, atterrissage et limites.

const DT := 1.0 / 120.0
const SPEED := 6.0
const ACCEL := 45.0
const DECEL := 60.0
const GRAVITY := 24.0


func _step(body: PlayerBody, axis: float, air_control := 0.45, x_min := -12.0, x_max := -0.3) -> bool:
	return body.step(DT, axis, SPEED, ACCEL, DECEL, air_control, GRAVITY, x_min, x_max)


func test_acceleration_reaches_but_never_exceeds_max_speed() -> void:
	var body := PlayerBody.new()
	body.position.x = -8.0
	var peak := 0.0
	for i in 200:
		_step(body, 1.0)
		peak = maxf(peak, body.velocity.x)
	assert_near(peak, SPEED, 1e-9, "vitesse maximale atteinte, pas dépassée")
	var body2 := PlayerBody.new()
	body2.position.x = -8.0
	for i in int(0.5 * 120):   # 0,5 s à 45 m/s² → 6 m/s est atteint à 0,133 s
		_step(body2, 1.0)
	assert_near(body2.velocity.x, SPEED, 1e-9, "atteinte en moins de 0,5 s")


func test_acceleration_is_linear_at_the_configured_rate() -> void:
	var body := PlayerBody.new()
	body.position.x = -8.0
	for i in 12:   # 0,1 s
		_step(body, 1.0)
	assert_near(body.velocity.x, ACCEL * 0.1, 1e-9, "v = a·t")


func test_stops_at_the_configured_deceleration() -> void:
	var body := PlayerBody.new()
	body.position.x = -8.0
	body.velocity.x = SPEED
	for i in 12:   # 0,1 s
		_step(body, 0.0)
	assert_near(body.velocity.x, SPEED - DECEL * 0.1, 1e-9, "freinage linéaire")
	for i in 60:
		_step(body, 0.0)
	assert_eq(body.velocity.x, 0.0, "arrêt complet")


func test_boundary_stops_the_player_and_kills_outward_velocity() -> void:
	var body := PlayerBody.new()
	body.position.x = -1.0
	for i in 240:
		_step(body, 1.0)
		assert_true(body.position.x <= -0.3 + 1e-6, "jamais au-delà de la limite (x = %s)" % body.position.x)
	assert_near(body.position.x, -0.3, 1e-6, "collé à la limite")
	assert_true(body.velocity.x <= 0.0, "vitesse vers l'extérieur annulée")
	body.position.x = -11.9
	for i in 240:
		_step(body, -1.0)
	assert_near(body.position.x, -12.0, 1e-6, "limite gauche")


func test_jump_apex_matches_the_requested_height() -> void:
	var body := PlayerBody.new()
	var apex := 1.5
	body.jump(sqrt(2.0 * GRAVITY * apex))
	assert_false(body.grounded, "en l'air")
	var peak := 0.0
	var landed_count := 0
	for i in 400:
		if _step(body, 0.0):
			landed_count += 1
		peak = maxf(peak, body.position.y)
	assert_near(peak, apex, 0.005, "hauteur atteinte")
	assert_eq(landed_count, 1, "un seul atterrissage signalé")
	assert_true(body.grounded and body.position.y == 0.0 and body.velocity.y == 0.0, "retour exact au sol")


func test_jump_flight_time_matches_physics() -> void:
	var body := PlayerBody.new()
	var v0 := 8.0
	body.jump(v0)
	var ticks := 0
	while not body.grounded and ticks < 1000:
		_step(body, 0.0)
		ticks += 1
	assert_near(ticks * DT, 2.0 * v0 / GRAVITY, 2.0 * DT, "durée du saut = 2·v0/g")


func test_cannot_jump_while_airborne() -> void:
	var body := PlayerBody.new()
	body.jump(8.0)
	for i in 20:
		_step(body, 0.0)
	var vy := body.velocity.y
	body.jump(20.0)
	assert_eq(body.velocity.y, vy, "second saut ignoré")


func test_air_control_scales_horizontal_acceleration_in_the_air() -> void:
	var weak := PlayerBody.new()
	var strong := PlayerBody.new()
	weak.position.x = -8.0
	strong.position.x = -8.0
	weak.jump(8.0)
	strong.jump(8.0)
	for i in 12:
		_step(weak, 1.0, 0.0)
		_step(strong, 1.0, 1.0)
	assert_eq(weak.velocity.x, 0.0, "contrôle aérien 0 : aucune poussée")
	assert_near(strong.velocity.x, ACCEL * 0.1, 1e-9, "contrôle aérien 1 : poussée comme au sol")
