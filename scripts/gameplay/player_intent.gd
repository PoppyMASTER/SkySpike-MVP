class_name PlayerIntent
extends RefCounted
## Ce qu'un joueur veut faire pendant un tick. Produit par le clavier, la manette ou l'IA
## (même structure : l'IA n'a aucun pouvoir spécial). Les « appuis » sont des fronts : vrais
## pour un seul tick, quelle que soit la durée de l'appui.

## -1 (gauche) à 1 (droite). Sert aussi de visée en tir : direction tenue au moment du contact.
var move_axis := 0.0
## Saut au sol, smash en l'air, saut de bloc après la posture, saut de service.
var jump_pressed := false
## Réception au sol ; feinte en l'air.
var receive_pressed := false
## Maintien de la touche réception/bloc (posture de bloc près du filet).
var receive_held := false
var set_pressed := false
var serve_pressed := false
## Touche de passe / service maintenue : charge du lancer pendant la tenue du ballon.
var serve_held := false


static func make(axis := 0.0, jump := false, receive := false, held := false, set_action := false, serve := false, serve_hold := false) -> PlayerIntent:
	var i := PlayerIntent.new()
	i.move_axis = clampf(axis, -1.0, 1.0)
	i.jump_pressed = jump
	i.receive_pressed = receive
	i.receive_held = held or receive
	i.set_pressed = set_action
	i.serve_pressed = serve
	i.serve_held = serve_hold or serve
	return i


## Un seul appui est traité par tick. Priorité : service > saut > passe > réception.
## `with_serve` = faux hors service : la touche L déclenche alors la passe, pas un service.
func first_press(with_serve := true) -> StringName:
	if serve_pressed and with_serve:
		return &"serve"
	if jump_pressed:
		return &"jump"
	if set_pressed:
		return &"set"
	if receive_pressed:
		return &"receive"
	return &""


func to_text() -> String:
	return "axis=%s jump=%s receive=%s held=%s set=%s serve=%s" % [
		move_axis, jump_pressed, receive_pressed, receive_held, set_pressed, serve_pressed]
