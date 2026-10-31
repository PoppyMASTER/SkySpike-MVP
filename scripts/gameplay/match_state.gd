class_name MatchState
extends RefCounted
## Vue en lecture seule de la simulation à la fin d'un tick. Recréée à chaque tick :
## le rendu, l'IA et le debug ne voient que ceci, jamais les objets internes.

var tick := 0
## Durée d'un tick (s) : sert au rendu à convertir le tick en temps pour les animations.
var tick_seconds := 0.0
var seed_value := 0
var ball_position := Vector2.ZERO
var ball_velocity := Vector2.ZERO
var ball_radius := 0.0
var ball_held := false
var court_half_length := 0.0
var net_height := 0.0
var net_half_thickness := 0.0
var players: Array[PlayerSnapshot] = []
## Rallye et score.
var phase: int = Enums.Phase.BALL_LIVE
var phase_time := 0.0
var score: Array[int] = [0, 0]
var serving_team := 0
var server_slot := 0
var touches: Array[int] = [0, 0]
var last_team := -1
var last_slot := -1
var last_was_block := false
var contact_seq := 0
var served := false
var winner := -1
var point_winner := -1
var fault_text := ""
var human_slot := -1
## Prévision du service du joueur humain (null si ce n'est pas à lui de servir). Hors empreinte.
var serve_preview: ServePreview


## Texte stable et exact (flottants en hexadécimal) pour comparer deux exécutions.
func fingerprint() -> String:
	var parts := PackedStringArray([str(tick), _hex(ball_position.x), _hex(ball_position.y),
		_hex(ball_velocity.x), _hex(ball_velocity.y), _hex(ball_radius),
		str(phase), str(score[0]), str(score[1]), str(touches[0]), str(touches[1]), str(contact_seq)])
	for player in players:
		for value: Variant in player.fingerprint_parts():
			parts.append(_hex(float(value)))
	return "|".join(parts)


static func _hex(v: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, v)
	return bytes.hex_encode()
