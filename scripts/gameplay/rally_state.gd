class_name RallyState
extends RefCounted
## État du rallye et du score. Modifié seulement par Referee et MatchSim.

var phase: int = Enums.Phase.READY
var phase_time := 0.0
var serving_team := 0
var server_slot := 0
var score: Array[int] = [0, 0]
## Touches comptées pour chaque équipe depuis que le ballon est de son côté.
var touches: Array[int] = [0, 0]
var last_team := -1
var last_slot := -1
## Dernier contact = touche de bloc (non comptée, pas de double touche possible juste après).
var last_was_block := false
var last_quality := 0.0
## Le service a-t-il été frappé ?
var served := false
## Nombre total de contacts (sert à l'IA à détecter un nouveau coup).
var contact_seq := 0
var winner := -1
var point_winner := -1
var fault_text := ""
## Index du serveur dans chaque équipe (0 = attaquant, 1 = passeur, 2 = défenseur).
var server_index: Array[int] = [0, 0]


func start_rally() -> void:
	touches = [0, 0]
	last_team = -1
	last_slot = -1
	last_was_block = false
	last_quality = 0.0
	served = false
	point_winner = -1
	fault_text = ""
