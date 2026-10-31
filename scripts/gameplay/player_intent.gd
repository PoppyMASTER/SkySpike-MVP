class_name PlayerIntent
extends RefCounted
## Ce qu'un joueur veut faire pendant un tick. Produit par le clavier, la manette ou l'IA ;
## la simulation ne sait jamais d'où il vient. Les « appuis » sont des fronts : vrais
## pour un seul tick, quelle que soit la durée de l'appui.

## -1 (gauche) à 1 (droite).
var move_axis := 0.0
## Saut au sol, smash en l'air.
var jump_pressed := false
## Réception (au sol).
var receive_pressed := false


static func make(axis := 0.0, jump := false, receive := false) -> PlayerIntent:
	var i := PlayerIntent.new()
	i.move_axis = clampf(axis, -1.0, 1.0)
	i.jump_pressed = jump
	i.receive_pressed = receive
	return i


func to_text() -> String:
	return "axis=%s jump=%s receive=%s" % [move_axis, jump_pressed, receive_pressed]
