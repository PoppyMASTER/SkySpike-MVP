class_name SweepHit
extends RefCounted
## Résultat d'un balayage : fraction du déplacement faite avant le contact (0 à 1),
## normale de la surface touchée (vers l'extérieur) et centre du cercle au moment du contact.

var t := 0.0
var normal := Vector2.ZERO
var center := Vector2.ZERO
