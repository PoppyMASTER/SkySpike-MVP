class_name HitIntensity
extends RefCounted
## Intensité de présentation d'une frappe (effets visuels ET sons), de 0 à 1. Fonction pure des données réelles du
## contact (vitesse, qualité, type de service CONFIRMÉ) et des réglages d'affichage ; aucun effet sur la simulation.
##   I = clamp(vitesse / vitesse_pleine(type), 0, 1) × (plancher + (1 − plancher) × qualité)
## Une frappe est « exceptionnelle » (éclair, lignes de vitesse, caméra) seulement si c'est un smash à la fois rapide
## et propre : une frappe rapide mais imparfaite garde sa puissance (I élevé) sans les effets réservés.

## Vitesse de pleine intensité des frappes hors service (attaque, passe…) : calibration d'affichage.
const GENERIC_SPEED_FULL := 24.0


static func speed_full(kind: String, params: ParamStore) -> float:
	match kind:
		"ground":
			return params.get_value(ParamIds.FX_SPEED_FULL_GROUND)
		"float":
			return params.get_value(ParamIds.FX_SPEED_FULL_FLOAT)
		"smash":
			return params.get_value(ParamIds.FX_SPEED_FULL_SMASH)
	return GENERIC_SPEED_FULL


static func compute(speed: float, quality: float, kind: String, params: ParamStore) -> float:
	var floor_ratio: float = params.get_value(ParamIds.FX_QUALITY_FLOOR)
	var s := clampf(speed / maxf(speed_full(kind, params), 0.1), 0.0, 1.0)
	return s * (floor_ratio + (1.0 - floor_ratio) * clampf(quality, 0.0, 1.0))


static func is_exceptional(speed: float, quality: float, kind: String, params: ParamStore) -> bool:
	if kind != "smash":
		return false
	return quality >= params.get_value(ParamIds.FX_MIN_QUALITY) \
		and speed >= params.get_value(ParamIds.FX_MIN_SPEED_RATIO) * speed_full(kind, params)
