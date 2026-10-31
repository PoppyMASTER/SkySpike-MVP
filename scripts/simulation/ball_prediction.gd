class_name BallPrediction
extends RefCounted
## Où va le ballon s'il n'est plus touché : trajectoire d'ici au sol (ou au filet) et point d'atterrissage.
## Formule fermée, sans frottement de l'air (estimation si `air_drag` > 0). Pure : pas d'état, pas de hasard.

const SAMPLES := 40

var path := PackedVector2Array()
var landing_x := 0.0
## Le ballon touche le filet avant le sol.
var hits_net := false
## Retombe dans les lignes.
var lands_inside := false
var flight_time := 0.0


## null si le ballon est tenu, posé, ou ne retombera jamais.
static func compute(position: Vector2, velocity: Vector2, radius: float, gravity: float, net_height: float, half_length: float) -> BallPrediction:
	var t_end := Ballistics.time_to_height(position.y, velocity.y, gravity, radius)
	if t_end <= 0.0:
		return null
	var out := BallPrediction.new()
	if absf(velocity.x) > 1e-6:
		var t_net := -position.x / velocity.x
		if t_net > 0.0 and t_net < t_end:
			var at_net := Ballistics.position_at(position, velocity, gravity, t_net)
			if at_net.y < net_height + radius:
				out.hits_net = true
				t_end = t_net
	out.flight_time = t_end
	for i in SAMPLES + 1:
		out.path.append(Ballistics.position_at(position, velocity, gravity, t_end * float(i) / SAMPLES))
	out.landing_x = out.path[SAMPLES].x
	out.lands_inside = not out.hits_net and absf(out.landing_x) <= half_length
	return out
