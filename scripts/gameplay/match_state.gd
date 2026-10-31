class_name MatchState
extends RefCounted
## Vue en lecture seule de la simulation à la fin d'un tick. Copiée à chaque tick :
## le rendu, l'IA et le debug ne voient que ceci, jamais les objets internes.
## J2 : tick, graine, ballon, terrain et joueurs. Le rallye et le score arrivent au J3.

var tick := 0
var seed_value := 0
var ball_position := Vector2.ZERO
var ball_velocity := Vector2.ZERO
var ball_radius := 0.0
var court_half_length := 0.0
var net_height := 0.0
var net_half_thickness := 0.0
var players: Array[PlayerSnapshot] = []


## Texte stable et exact (flottants en hexadécimal) pour comparer deux exécutions.
func fingerprint() -> String:
	var parts := PackedStringArray([str(tick), _hex(ball_position.x), _hex(ball_position.y),
		_hex(ball_velocity.x), _hex(ball_velocity.y), _hex(ball_radius)])
	for player in players:
		for value: Variant in player.fingerprint_parts():
			parts.append(_hex(float(value)))
	return "|".join(parts)


static func _hex(v: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, v)
	return bytes.hex_encode()
