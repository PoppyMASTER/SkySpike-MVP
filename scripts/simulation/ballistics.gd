class_name Ballistics
extends RefCounted
## Trajectoires sans frottement (formules fermées) : prévision de l'IA, cibles de la visée assistée.
## y vers le haut, g > 0 en m/s². Le jeu peut activer un frottement de l'air : ces fonctions
## restent des estimations (c'est aussi le cas pour l'IA, qui n'a aucun pouvoir spécial).


static func position_at(from: Vector2, velocity: Vector2, gravity: float, t: float) -> Vector2:
	return from + velocity * t + Vector2(0.0, -0.5 * gravity * t * t)


## Premier instant t ≥ 0 où la hauteur vaut `target_y` pendant la descente (ou la montée si
## `descending` est faux). -1 si la trajectoire n'y passe pas.
static func time_to_height(from_y: float, vy: float, gravity: float, target_y: float, descending := true) -> float:
	var disc := vy * vy + 2.0 * gravity * (from_y - target_y)
	if disc < 0.0 or gravity <= 0.0:
		return -1.0
	var root := sqrt(disc)
	var t_down := (vy + root) / gravity
	var t_up := (vy - root) / gravity
	if descending:
		return t_down if t_down >= 0.0 else -1.0
	return t_up if t_up >= 0.0 else (t_down if t_down >= 0.0 else -1.0)


## Vitesse initiale pour aller de `from` à `to` en `flight_time` secondes.
static func velocity_for_arrival(from: Vector2, to: Vector2, flight_time: float, gravity: float) -> Vector2:
	var t := maxf(flight_time, 1e-3)
	return Vector2((to.x - from.x) / t, (to.y - from.y) / t + 0.5 * gravity * t)


## Angle de tir (rad au-dessus de l'horizontale, vers `target`) pour qu'un tir de vitesse `speed`
## passe par `target`. `high` choisit la trajectoire en cloche. NAN si hors de portée.
static func angle_to_pass(from: Vector2, speed: float, target: Vector2, gravity: float, high: bool) -> float:
	var dx := absf(target.x - from.x)
	var dy := target.y - from.y
	if dx < 1e-3 or speed <= 0.0:
		return NAN
	var v2 := speed * speed
	var disc := v2 * v2 - gravity * (gravity * dx * dx + 2.0 * dy * v2)
	if disc < 0.0:
		return NAN
	var root := sqrt(disc)
	return atan((v2 + root) / (gravity * dx)) if high else atan((v2 - root) / (gravity * dx))
