class_name SimClock
extends RefCounted
## Accumulateur de temps à pas fixe. Transforme le temps réel écoulé en un nombre entier
## de ticks de simulation. Le ralenti réduit le nombre de ticks par seconde réelle,
## il ne change jamais la durée d'un tick : le résultat logique reste identique.

var dt: float
var time_scale := 1.0
## Plafond du temps réel pris en compte par image (évite la spirale après un gel).
var max_frame_s := 0.1
## Plafond de ticks exécutés par image ; le surplus est abandonné et compté.
var max_ticks_per_frame := 8
var paused := false

var tick := 0
var dropped_ticks := 0
var _accumulator := 0.0
var _pending_steps := 0


func _init(sim_hz: float) -> void:
	dt = 1.0 / sim_hz


## Ajoute le temps réel de l'image et renvoie le nombre de ticks à exécuter maintenant.
func advance(real_delta: float) -> int:
	if paused:
		var steps := _pending_steps
		_pending_steps = 0
		return steps
	_accumulator += minf(real_delta, max_frame_s) * time_scale
	var steps := 0
	while _accumulator >= dt:
		_accumulator -= dt
		if steps < max_ticks_per_frame:
			steps += 1
		else:
			dropped_ticks += 1
	return steps


## En pause : demande d'exécuter un seul tick à la prochaine image (mode pas à pas).
func request_single_step() -> void:
	_pending_steps += 1


## À appeler par le propriétaire après chaque tick exécuté.
func on_tick_done() -> void:
	tick += 1


## Fraction du tick suivant déjà écoulée, pour interpoler le rendu (0..1).
func alpha() -> float:
	return clampf(_accumulator / dt, 0.0, 1.0)
