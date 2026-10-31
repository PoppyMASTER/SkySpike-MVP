class_name ServeCharge
extends RefCounted
## Machine à états du début du service : appui bref ou maintien, charge, relâchement, annulation.
##   IDLE ──appui──► PRESSING (< serve_tap_max_s) ──relâché──► lancer BAS (service au sol)
##                       └ maintenu ──► CHARGING (hauteur et avance croissantes) ──relâché──► lancer HAUT
##   PRESSING / CHARGING ──annulation──► IDLE
## Pur calcul de durées : aucun hasard, aucune lecture de l'horloge. Un appui n'est pris en compte qu'une fois
## (front d'appui), donc un maintien commencé avant la tenue du ballon ne déclenche rien.

enum Result { NONE, TOSS, CANCELLED }

var active := false
## Durée de maintien depuis l'appui (s).
var held := 0.0


func reset() -> void:
	active = false
	held = 0.0


## Avance d'un tick. `TOSS` = relâché, le ballon doit partir maintenant ; `CANCELLED` = annulé.
func update(intent: PlayerIntent, dt: float, p: ParamStore) -> int:
	if intent.serve_pressed and not active:
		active = true
		held = 0.0
	if not active:
		return Result.NONE
	if intent.receive_pressed:   # annulation avant le lancer
		reset()
		return Result.CANCELLED
	if intent.serve_held:
		held += dt
		return Result.NONE
	return Result.TOSS


## Appui bref : lancer bas, service au sol.
func is_tap(p: ParamStore) -> bool:
	return held < p.get_value(ParamIds.SERVE_TAP_MAX_S)


## Charge de 0 à 1 (0 pendant l'appui bref).
func fraction(p: ParamStore) -> float:
	if is_tap(p):
		return 0.0
	var span := maxf(p.get_value(ParamIds.SERVE_CHARGE_TIME), 1e-6)
	return clampf((held - p.get_value(ParamIds.SERVE_TAP_MAX_S)) / span, 0.0, 1.0)


## Vitesse du ballon au lancer : plus la charge est longue, plus il monte et avance vers le filet.
func toss_velocity(p: ParamStore, facing: int) -> Vector2:
	var forward_min: float = p.get_value(ParamIds.SERVE_TOSS_FORWARD_MIN)
	if is_tap(p):
		return Vector2(facing * forward_min, p.get_value(ParamIds.SERVE_TOSS_LOW_SPEED))
	var f := fraction(p)
	return Vector2(facing * lerpf(forward_min, p.get_value(ParamIds.SERVE_TOSS_FORWARD), f),
		lerpf(p.get_value(ParamIds.SERVE_TOSS_SPEED), p.get_value(ParamIds.SERVE_TOSS_SPEED_MAX), f))
