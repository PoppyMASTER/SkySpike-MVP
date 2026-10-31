class_name PlayerSnapshot
extends RefCounted
## Copie en lecture seule d'un joueur à la fin d'un tick (pour le rendu, le debug, l'IA).

var slot := 0
var team := 0
var role: int = Enums.Role.ATTACKER
var character_id := ""
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var facing := 1
var grounded := true
var action: int = Enums.ActionState.FREE
var action_time := 0.0
## Zones de réception et de smash à la position actuelle (centre et rayon, en mètres).
var receive_center := Vector2.ZERO
var receive_radius := 0.0
var spike_center := Vector2.ZERO
var spike_radius := 0.0
## Zone dont la fenêtre est ouverte à cet instant ("" = aucune, sinon l'action ou "block").
var active_kind := ""
var active_center := Vector2.ZERO
var active_radius := 0.0


func fingerprint_parts() -> Array:
	return [position.x, position.y, velocity.x, velocity.y, action, action_time]
