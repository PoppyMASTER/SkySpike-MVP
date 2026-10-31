class_name StatConversion
extends RefCounted
## Conversion des stats (0–100) en grandeurs physiques. Toutes les bornes et courbes
## viennent des paramètres : valeur = min + (max − min) × (stat / 100)^courbe.

static func curve(stat: int, min_value: float, max_value: float, exponent: float) -> float:
	var t := clampf(stat / 100.0, 0.0, 1.0)
	return min_value + (max_value - min_value) * pow(t, exponent)


## Vitesse de course max au sol (m/s).
static func run_speed(stats: StatsDefinition, p: ParamStore) -> float:
	return curve(stats.speed, p.get_value(ParamIds.SPEED_MIN), p.get_value(ParamIds.SPEED_MAX),
		p.get_value(ParamIds.SPEED_CURVE))


## Hauteur d'apogée des pieds lors d'un saut (m).
static func jump_apex(stats: StatsDefinition, p: ParamStore) -> float:
	return curve(stats.jump, p.get_value(ParamIds.JUMP_APEX_MIN), p.get_value(ParamIds.JUMP_APEX_MAX),
		p.get_value(ParamIds.JUMP_CURVE))


## Vitesse de sortie d'un smash à qualité parfaite (m/s).
static func spike_speed(stats: StatsDefinition, p: ParamStore) -> float:
	return curve(stats.attack_power, p.get_value(ParamIds.SPIKE_SPEED_MIN), p.get_value(ParamIds.SPIKE_SPEED_MAX),
		p.get_value(ParamIds.POWER_CURVE))


## Vitesse de sortie d'un service à qualité parfaite (m/s).
static func serve_speed(stats: StatsDefinition, p: ParamStore) -> float:
	return curve(stats.attack_power, p.get_value(ParamIds.SERVE_SPEED_MIN), p.get_value(ParamIds.SERVE_SPEED_MAX),
		p.get_value(ParamIds.POWER_CURVE))


## Vitesse maximale d'une passe (m/s), donc sa portée.
static func set_speed_max(stats: StatsDefinition, p: ParamStore) -> float:
	return curve(stats.set_power, p.get_value(ParamIds.SET_SPEED_MIN), p.get_value(ParamIds.SET_SPEED_MAX),
		p.get_value(ParamIds.POWER_CURVE))


## Écart-type d'angle d'un smash à qualité parfaite (rad) : plus la stat est haute, plus il est petit.
static func spike_angle_noise(stats: StatsDefinition, p: ParamStore) -> float:
	return curve(stats.spike_accuracy, p.get_value(ParamIds.SPIKE_NOISE_AT_0), p.get_value(ParamIds.SPIKE_NOISE_AT_100),
		p.get_value(ParamIds.ACCURACY_CURVE))


static func set_angle_noise(stats: StatsDefinition, p: ParamStore) -> float:
	return curve(stats.set_accuracy, p.get_value(ParamIds.SET_NOISE_AT_0), p.get_value(ParamIds.SET_NOISE_AT_100),
		p.get_value(ParamIds.ACCURACY_CURVE))


static func receive_angle_noise(stats: StatsDefinition, p: ParamStore) -> float:
	return curve(stats.receive, p.get_value(ParamIds.RECEIVE_NOISE_AT_0), p.get_value(ParamIds.RECEIVE_NOISE_AT_100),
		p.get_value(ParamIds.ACCURACY_CURVE))


## Terme « bloc » du calcul attaque contre bloc (sans unité).
static func block_factor(stats: StatsDefinition, p: ParamStore) -> float:
	return curve(stats.block, p.get_value(ParamIds.BLOCK_FACTOR_MIN), p.get_value(ParamIds.BLOCK_FACTOR_MAX),
		p.get_value(ParamIds.BLOCK_CURVE))
