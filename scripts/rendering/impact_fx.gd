class_name ImpactFx
extends RefCounted
## Effets visuels de frappe : impacts, traînée du ballon, indicateur de vitesse, secousse de caméra.
## Entièrement fonction du TEMPS DE SIMULATION (tick × durée d'un tick) : la pause les fige, le ralenti les
## ralentit, aucun hasard, aucune lecture d'horloge. Lit des états et des événements déjà produits ; ne modifie
## rien dans la simulation, ne décide d'aucun contact et n'a aucun effet sur la physique.

## Vitesse (m/s) à partir de laquelle un effet atteint son intensité maximale.
const SPEED_FULL := 24.0
const IMPACT_LIFE_S := 0.35
const SPEED_LABEL_LIFE_S := 1.2
const CAMERA_LIFE_S := 0.25
const CAMERA_MAX_PX := 9.0
const CAMERA_MIN_SPEED := 14.0
const CAMERA_FREQUENCY_HZ := 22.0
const MAX_TRAIL_POINTS := 240
const MS_TO_KMH := 3.6
## Intensité (0 à 1) selon le type de service : simple, flottant, smashé.
const SERVE_KIND_WEIGHT := {"ground": 0.35, "float": 0.6, "smash": 1.0}

class Impact:
	var position := Vector2.ZERO
	var born := 0.0
	var speed := 0.0
	var direction := Vector2.RIGHT
	var weight := 0.5
	var action := ""
	var serve_kind := ""

var impacts: Array[Impact] = []
## Traînée : points (position, temps de simulation, vitesse).
var trail: Array[Dictionary] = []
var _last_tick := -1


func clear() -> void:
	impacts.clear()
	trail.clear()
	_last_tick = -1


## Appelé à chaque tick avec le nouvel état : mémorise la traînée.
func on_state(state: MatchState, trail_seconds: float) -> void:
	if state.tick < _last_tick:   # match relancé
		clear()
	if state.tick == _last_tick:
		return
	_last_tick = state.tick
	var now := time_of(state)
	if not state.ball_held:
		trail.append({"p": state.ball_position, "t": now, "v": state.ball_velocity.length()})
		while trail.size() > MAX_TRAIL_POINTS:
			trail.pop_front()
	else:
		trail.clear()
	while not trail.is_empty() and now - float(trail[0].t) > trail_seconds:
		trail.pop_front()
	while not impacts.is_empty() and now - impacts[0].born > SPEED_LABEL_LIFE_S:
		impacts.pop_front()


## Appelé avec les événements d'un tick : un impact par contact.
func on_events(events: Array[MatchEvent], state: MatchState) -> void:
	for e in events:
		if e.type != MatchEvent.Type.CONTACT:
			continue
		var d: Dictionary = e.details
		var fx := Impact.new()
		fx.position = state.ball_position
		fx.born = time_of(state)
		fx.speed = float(d.get("speed", 0.0))
		fx.direction = state.ball_velocity.normalized() if state.ball_velocity.length() > 0.01 else Vector2.RIGHT
		fx.action = String(d.get("action", ""))
		fx.serve_kind = String(d.get("serve_kind", ""))
		fx.weight = clampf(fx.speed / SPEED_FULL, 0.1, 1.0)
		if fx.serve_kind != "":
			fx.weight = maxf(fx.weight, float(SERVE_KIND_WEIGHT.get(fx.serve_kind, 0.5)) * clampf(fx.speed / SPEED_FULL + 0.4, 0.4, 1.0))
		impacts.append(fx)


static func time_of(state: MatchState) -> float:
	return float(state.tick) * state.tick_seconds


## Avancement (0 → 1) d'un impact à l'instant `now`, ou -1 s'il est terminé.
static func impact_progress(fx: Impact, now: float) -> float:
	var age := now - fx.born
	return age / IMPACT_LIFE_S if age >= 0.0 and age <= IMPACT_LIFE_S else -1.0


## Épaisseur (px) de la traînée pour une vitesse donnée.
static func trail_width(speed: float, base_px: float) -> float:
	return base_px * (0.5 + 1.5 * clampf(speed / SPEED_FULL, 0.0, 1.0))


## Intensité de la traînée (0 à 1) pour une vitesse donnée : une balle lente laisse à peine de trace.
static func trail_strength(speed: float) -> float:
	return clampf((speed - 4.0) / (SPEED_FULL - 4.0), 0.0, 1.0)


## Décalage de caméra (px) à l'instant `now` : secousse amortie dans la direction de la frappe, plafonnée.
## Seules les frappes rapides déclenchent une secousse.
func camera_offset(now: float, strength: float) -> Vector2:
	var out := Vector2.ZERO
	if strength <= 0.0:
		return out
	for fx in impacts:
		var age := now - fx.born
		if age < 0.0 or age > CAMERA_LIFE_S or fx.speed < CAMERA_MIN_SPEED:
			continue
		var amp := clampf((fx.speed - CAMERA_MIN_SPEED) / (SPEED_FULL - CAMERA_MIN_SPEED), 0.0, 1.0) * CAMERA_MAX_PX * strength
		var fade := 1.0 - age / CAMERA_LIFE_S
		out += Vector2(fx.direction.x, -fx.direction.y) * amp * fade * fade * cos(TAU * CAMERA_FREQUENCY_HZ * age)
	return out.limit_length(CAMERA_MAX_PX)
