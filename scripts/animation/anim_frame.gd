class_name AnimFrame
extends RefCounted
## Résultat d'une évaluation d'animation pour un joueur à un instant de rendu.

## Pose finale {os: angle}.
var pose: Dictionary = {}
## Décalage vertical du rig (m, y vers le bas) pour poser les semelles sur le sol (joueur au sol uniquement).
var shift_y := 0.0
var clip_id := ""
var action := ""
var domain := ""
var clip_time := 0.0
var duration := 0.0
## Fondu depuis l'animation précédente : 0 = début, 1 = terminé.
var blend := 1.0


func progress() -> float:
	return clampf(clip_time / duration, 0.0, 1.0) if duration > 0.0 else 0.0
