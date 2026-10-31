class_name ServeCharge
extends RefCounted
## Charge du lancer de service : L maintenu pendant la tenue du ballon, plus on tient, plus le ballon
## monte. Relâcher le lance. Pur calcul de durée : aucun hasard, aucune lecture de l'horloge.

var active := false
var charge := 0.0


func reset() -> void:
	active = false
	charge = 0.0


## Avance d'un tick. Renvoie vrai quand le joueur relâche : le ballon doit être lancé maintenant.
func update(intent: PlayerIntent, dt: float, p: ParamStore) -> bool:
	if intent.serve_pressed and not active:
		active = true
		charge = 0.0
	if not active:
		return false
	if intent.serve_held:
		charge = minf(charge + dt, p.get_value(ParamIds.SERVE_CHARGE_TIME))
		return false
	return true


## Charge de 0 à 1.
func fraction(p: ParamStore) -> float:
	return clampf(charge / maxf(p.get_value(ParamIds.SERVE_CHARGE_TIME), 1e-6), 0.0, 1.0)


## Vitesse du ballon au lancer : avance de base vers le filet, hauteur selon la charge.
func toss_velocity(p: ParamStore, facing: int) -> Vector2:
	var up := lerpf(p.get_value(ParamIds.SERVE_TOSS_SPEED), p.get_value(ParamIds.SERVE_TOSS_SPEED_MAX), fraction(p))
	return Vector2(facing * p.get_value(ParamIds.SERVE_TOSS_FORWARD), up)
