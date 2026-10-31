class_name BallBody
extends RefCounted
## Ballon : état physique pur, en mètres et secondes. x horizontal (filet en x = 0),
## y vertical (sol en y = 0, vers le haut).

var position := Vector2.ZERO
var velocity := Vector2.ZERO
var radius := 0.105


## Avance d'un pas `dt` sous gravité `gravity` (m/s², vers le bas) et frottement `drag` (1/s).
## Sans frottement : intégration exacte à accélération constante (aucune dérive numérique).
## Avec frottement : Euler semi-implicite.
func step(dt: float, gravity: float, drag: float) -> void:
	var accel := Vector2(0.0, -gravity)
	if drag <= 0.0:
		position += velocity * dt + 0.5 * accel * dt * dt
		velocity += accel * dt
	else:
		velocity += (accel - velocity * drag) * dt
		position += velocity * dt


func copy() -> BallBody:
	var out := BallBody.new()
	out.position = position
	out.velocity = velocity
	out.radius = radius
	return out
