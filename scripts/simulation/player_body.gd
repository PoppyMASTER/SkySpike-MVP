class_name PlayerBody
extends RefCounted
## Corps physique d'un joueur (point aux pieds, mètres et secondes). Ne connaît ni les règles
## ni les actions : il court, saute, retombe et reste dans ses limites.

var position := Vector2.ZERO
var velocity := Vector2.ZERO
var grounded := true


## Décollage à la vitesse verticale `speed` (m/s). Sans effet en l'air.
func jump(speed: float) -> void:
	if not grounded:
		return
	grounded = false
	velocity.y = speed


## Avance d'un pas. `axis` : -1..1. Renvoie true si le joueur vient de toucher le sol.
## `air_control` multiplie accélération et freinage en l'air.
func step(dt: float, axis: float, max_speed: float, accel: float, decel: float,
		air_control: float, gravity: float, x_min: float, x_max: float) -> bool:
	var grip := 1.0 if grounded else air_control
	var wanted := clampf(axis, -1.0, 1.0)
	if wanted != 0.0:
		velocity.x = move_toward(velocity.x, wanted * max_speed, accel * grip * dt)
	else:
		velocity.x = move_toward(velocity.x, 0.0, decel * grip * dt)
	position.x += velocity.x * dt
	if position.x < x_min:
		position.x = x_min
		velocity.x = maxf(velocity.x, 0.0)
	elif position.x > x_max:
		position.x = x_max
		velocity.x = minf(velocity.x, 0.0)
	if grounded:
		return false
	position.y += velocity.y * dt - 0.5 * gravity * dt * dt
	velocity.y -= gravity * dt
	if position.y <= 0.0:
		position.y = 0.0
		velocity.y = 0.0
		grounded = true
		return true
	return false
