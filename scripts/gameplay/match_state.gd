class_name MatchState
extends RefCounted
## Vue en lecture seule de la simulation à la fin d'un tick. Copiée à chaque tick :
## le rendu, l'IA et le debug ne voient que ceci, jamais les objets internes.
## J1 : tick, graine et ballon. Les joueurs et le rallye arrivent aux J2 et J3.

var tick := 0
var seed_value := 0
var ball_position := Vector2.ZERO
var ball_velocity := Vector2.ZERO
var ball_radius := 0.0


func copy() -> MatchState:
	var s := MatchState.new()
	s.tick = tick
	s.seed_value = seed_value
	s.ball_position = ball_position
	s.ball_velocity = ball_velocity
	s.ball_radius = ball_radius
	return s


## Texte stable et exact (flottants en hexadécimal) pour comparer deux exécutions.
func fingerprint() -> String:
	return "%d|%s|%s|%s|%s|%s" % [tick, _hex(ball_position.x), _hex(ball_position.y),
		_hex(ball_velocity.x), _hex(ball_velocity.y), _hex(ball_radius)]


static func _hex(v: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, v)
	return bytes.hex_encode()
