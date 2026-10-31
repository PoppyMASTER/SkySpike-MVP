class_name StrikeRecord
extends RefCounted
## Mémoire de la dernière frappe de service d'un joueur, pour que l'animation puisse jouer le suivi du geste
## et l'atterrissage correspondant APRÈS la fin de la fenêtre de contact. Donnée d'affichage : elle est écrite
## par le gameplay au moment où la fenêtre se ferme (touchée ou ratée) et ne décide de rien.

const NONE_AGE := 999.0

## Intention annoncée à l'ouverture de la fenêtre (sol / flottant / smash), partagée avec l'animation.
var intent: StringName = &""
## Type RÉEL confirmé au contact (identique à l'intention dans le cas normal) ; "" tant qu'il n'y a pas eu de contact.
var real: StringName = &""
## Instant d'état (s) où le contact est attendu ; l'animation y cale l'impact visuel.
var expected := 0.0
var age := NONE_AGE
var kind: StringName = &""
var missed := false
## Temps d'état et instant idéal de la fenêtre à sa fermeture : permettent de reprendre le clip là où il en était.
var window_time := 0.0
var ideal := 0.0


func reset() -> void:
	intent = &""
	real = &""
	expected = 0.0
	age = NONE_AGE
	kind = &""
	missed = false


func tick(dt: float) -> void:
	age += dt


## Ferme la fenêtre : `contact` = type réel s'il y a eu contact, sinon "" (frappe manquée : le geste de l'intention se termine).
func close(contact: StringName, state_time: float, ideal_s: float) -> void:
	missed = contact == &""
	kind = intent if missed else contact
	window_time = state_time
	ideal = ideal_s
	age = 0.0
	real = &""
