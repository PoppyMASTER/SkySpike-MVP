class_name ImpactFx
extends RefCounted
## Effets visuels de frappe : impacts, traînée du ballon, indicateur de vitesse, secousse de caméra.
## Entièrement fonction du TEMPS DE SIMULATION (tick × durée d'un tick) : la pause les fige, le ralenti les
## ralentit, aucun hasard, aucune lecture d'horloge. Lit des états et des événements déjà produits ; ne modifie
## rien dans la simulation, ne décide d'aucun contact et n'a aucun effet sur la physique.
## J4.1 SJ2 : le style suit le type de service RÉEL du contact (jamais l'intention), l'intensité suit la vitesse et la
## qualité réelles (HitIntensity) ; une frappe manquée (ACTION_MISSED) ne produit aucun effet de contact.

const IMPACT_LIFE_S := 0.35
## Durée et taille relatives de l'anneau selon le type de service : le sol reste léger, le smash est le plus ample.
const KIND_LIFE := {"ground": 0.6, "float": 0.8, "smash": 1.0}
const KIND_SIZE := {"ground": 0.55, "float": 0.75, "smash": 1.0}
const FLASH_LIFE_S := 0.06
const SPEED_LINES_LIFE_S := 0.3
const SPEED_LABEL_LIFE_S := 1.2
## Secousse de caméra : très courte, discrète, plafonnée ; seulement pour un smash exceptionnel.
const CAMERA_LIFE_S := 0.15
const CAMERA_MAX_PX := 6.0
const CAMERA_FREQUENCY_HZ := 22.0
const MAX_TRAIL_POINTS := 240
const MS_TO_KMH := 3.6
## Vitesse sous laquelle le ballon ne laisse pas de traînée (m/s).
const TRAIL_MIN_SPEED := 4.0

class Impact:
	var position := Vector2.ZERO
	var born := 0.0
	var speed := 0.0
	var quality := 1.0
	var direction := Vector2.RIGHT
	## Intensité de présentation 0 → 1 (HitIntensity).
	var intensity := 0.5
	var action := ""
	## Type de service RÉEL ("ground", "float", "smash") ou "" pour une autre frappe.
	var kind := ""
	## Smash rapide et propre : éclair, lignes de vitesse, caméra.
	var exceptional := false

## Réglages d'affichage (lecture seule), posés par la vue.
var params: ParamStore
var impacts: Array[Impact] = []
## Traînée : points {p: position, t: temps de simulation, v: vitesse, k: type, i: intensité, life: durée (s), c: temps du contact}.
var trail: Array[Dictionary] = []
var _last_tick := -1
var _kind := ""
var _intensity := 0.0
var _contact_time := 0.0


func _init(store: ParamStore = null) -> void:
	params = store


func clear() -> void:
	impacts.clear()
	trail.clear()
	_last_tick = -1
	_kind = ""


## Appelé à chaque tick avec le nouvel état : mémorise la traînée.
func on_state(state: MatchState) -> void:
	if state.tick < _last_tick:   # match relancé
		clear()
	if state.tick == _last_tick:
		return
	_last_tick = state.tick
	var now := time_of(state)
	if not state.ball_held:
		trail.append({"p": state.ball_position, "t": now, "v": state.ball_velocity.length(), "k": _kind, "i": _intensity,
			"life": trail_life(_kind), "c": _contact_time})
		while trail.size() > MAX_TRAIL_POINTS:
			trail.pop_front()
	else:
		trail.clear()
		_kind = ""
	while not trail.is_empty() and now - float(trail[0].t) > float(trail[0].life):
		trail.pop_front()
	while not impacts.is_empty() and now - impacts[0].born > SPEED_LABEL_LIFE_S:
		impacts.pop_front()


## Appelé avec les événements d'un tick : un impact par contact réel (une frappe manquée n'en produit pas).
func on_events(events: Array[MatchEvent], state: MatchState) -> void:
	for e in events:
		if e.type != MatchEvent.Type.CONTACT:
			continue
		var d: Dictionary = e.details
		var fx := Impact.new()
		fx.position = state.ball_position
		fx.born = time_of(state)
		fx.speed = float(d.get("speed", 0.0))
		fx.quality = float(d.get("q", 1.0))
		fx.direction = state.ball_velocity.normalized() if state.ball_velocity.length() > 0.01 else Vector2.RIGHT
		fx.action = String(d.get("action", ""))
		fx.kind = String(d.get("serve_kind", ""))   # type CONFIRMÉ au contact, jamais « serve_intent »
		fx.intensity = HitIntensity.compute(fx.speed, fx.quality, fx.kind, params)
		fx.exceptional = HitIntensity.is_exceptional(fx.speed, fx.quality, fx.kind, params)
		impacts.append(fx)
		_kind = fx.kind
		_intensity = fx.intensity
		_contact_time = fx.born


static func time_of(state: MatchState) -> float:
	return float(state.tick) * state.tick_seconds


## Durée de vie (s) d'un point de traînée selon le type de frappe qui l'a lancé.
func trail_life(kind: String) -> float:
	match kind:
		"ground":
			return params.get_value(ParamIds.FX_TRAIL_GROUND_S)
		"float":
			return params.get_value(ParamIds.FX_TRAIL_FLOAT_S)
		"smash":
			return params.get_value(ParamIds.FX_TRAIL_SMASH_S)
	return params.get_value(ParamIds.FX_TRAIL_S)


## Avancement (0 → 1) d'un impact à l'instant `now`, ou -1 s'il est terminé.
static func impact_progress(fx: Impact, now: float) -> float:
	var age := now - fx.born
	var life := IMPACT_LIFE_S * float(KIND_LIFE.get(fx.kind, 1.0))
	return age / life if age >= 0.0 and age <= life else -1.0


## Épaisseur (px) de la traînée pour une vitesse donnée.
static func trail_width(speed: float, base_px: float) -> float:
	return base_px * (0.5 + 1.5 * clampf(speed / HitIntensity.GENERIC_SPEED_FULL, 0.0, 1.0))


## Intensité de la traînée (0 à 1) pour une vitesse donnée : une balle lente laisse à peine de trace.
static func trail_strength(speed: float) -> float:
	return clampf((speed - TRAIL_MIN_SPEED) / (HitIntensity.GENERIC_SPEED_FULL - TRAIL_MIN_SPEED), 0.0, 1.0)


## Décalage de caméra (px) à l'instant `now` : secousse amortie dans la direction de la frappe, plafonnée.
## Seul un service smashé rapide ET propre la déclenche.
func camera_offset(now: float, strength: float) -> Vector2:
	var out := Vector2.ZERO
	if strength <= 0.0:
		return out
	for fx in impacts:
		var age := now - fx.born
		if age < 0.0 or age > CAMERA_LIFE_S or not fx.exceptional:
			continue
		var fade := 1.0 - age / CAMERA_LIFE_S
		var amp := CAMERA_MAX_PX * clampf(strength, 0.0, 1.0) * fx.intensity
		out += Vector2(fx.direction.x, -fx.direction.y) * amp * fade * fade * cos(TAU * CAMERA_FREQUENCY_HZ * age)
	return out.limit_length(CAMERA_MAX_PX)
