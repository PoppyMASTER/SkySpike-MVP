class_name PlayerSnapshot
extends RefCounted
## Copie en lecture seule d'un joueur à la fin d'un tick (pour le rendu, le debug, l'IA).

## Zone active : aucune, réception ou smash.
enum Zone { NONE, RECEIVE, SPIKE }

var character_id := ""
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var facing := 1
var grounded := true
var action: int = Enums.ActionState.FREE
var action_time := 0.0
## Zones de contact (centre et rayon, en mètres) à la position actuelle du joueur.
var receive_center := Vector2.ZERO
var receive_radius := 0.0
var spike_center := Vector2.ZERO
var spike_radius := 0.0
## Zone dont la fenêtre est ouverte à cet instant.
var active_zone: int = Zone.NONE


func fingerprint_parts() -> Array:
	return [position.x, position.y, velocity.x, velocity.y, action, action_time]
