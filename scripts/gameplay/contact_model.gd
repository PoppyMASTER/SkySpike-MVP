class_name ContactModel
extends RefCounted
## Modèle de contact par fenêtre : fonctions pures, sans état. Voir docs/GAMEPLAY_REFERENCE.md.
##   e_t = (t − t_idéal) / tolérance      (signé : négatif = trop tôt)
##   e_s = distance au centre / rayon
##   q   = clamp(1 − w_t·e_t² − w_s·e_s², 0, 1)

## Limite de sécurité sur l'angle de sortie (n'est pas une valeur d'équilibrage).
const ANGLE_LIMIT := PI * 0.45


static func time_error(elapsed: float, ideal: float, tolerance: float) -> float:
	return (elapsed - ideal) / maxf(tolerance, 1e-6)


static func space_error(distance: float, radius: float) -> float:
	return distance / maxf(radius, 1e-6)


static func quality(e_t: float, e_s: float, w_time: float, w_space: float) -> float:
	return clampf(1.0 - w_time * e_t * e_t - w_space * e_s * e_s, 0.0, 1.0)


## Vitesse de sortie : `top_speed` à qualité 1, `top_speed × floor` à qualité 0.
static func speed(top_speed: float, q: float, floor_ratio: float) -> float:
	return top_speed * (floor_ratio + (1.0 - floor_ratio) * q)


## Angle de sortie au-dessus de l'horizontale (rad, vers l'avant du joueur).
## Trop tôt (e_t < 0) = plus haut ; vers l'avant (aim > 0) = plus tendu ; bruit déjà tiré.
static func exit_angle(base: float, e_t: float, shift: float, aim: float, aim_range: float, noise: float) -> float:
	return clampf(base - shift * e_t - aim * aim_range + noise, -ANGLE_LIMIT, ANGLE_LIMIT)


## Vecteur vitesse de sortie pour un joueur qui regarde dans le sens `facing` (1 ou -1).
static func exit_velocity(speed_value: float, angle: float, facing: int) -> Vector2:
	return Vector2(cos(angle) * facing, sin(angle)) * speed_value
