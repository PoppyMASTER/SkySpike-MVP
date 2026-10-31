class_name Enums
extends RefCounted
## Énumérations partagées par toutes les couches. Aucune chaîne magique pour les états.

enum Role { ATTACKER, SETTER, DEFENDER }

## États d'action d'un joueur (tableau de la Phase 0, section F). AIR = AIR_ATTACK ; LAND est
## fusionné avec RECOVER (durée d'atterrissage réglable).
enum ActionState {
	LOCKED, FREE, RECEIVE, SET, BLOCK_READY, AIR, SPIKE, FEINT, BLOCK_AIR, RECOVER,
	SERVE_HOLD, SERVE_TOSS, SERVE_JUMP, SERVE_HIT,
}

## Phases du match. MATCH_OVER s'ajoute au cycle de la Phase 0 (fin de la partie).
enum Phase { READY, SERVE_PREP, BALL_LIVE, POINT_AWARDED, RESET, MATCH_OVER }

const ROLE_NAMES: Dictionary = {
	Role.ATTACKER: "attacker",
	Role.SETTER: "setter",
	Role.DEFENDER: "defender",
}


## "attacker" -> Role.ATTACKER ; -1 si inconnu.
static func role_from_string(text: String) -> int:
	for role: int in ROLE_NAMES:
		if ROLE_NAMES[role] == text:
			return role
	return -1


static func role_to_string(role: int) -> String:
	return ROLE_NAMES.get(role, "unknown")


static func action_to_string(state: int) -> String:
	return ActionState.keys()[state] if state >= 0 and state < ActionState.size() else "UNKNOWN"


static func phase_to_string(phase: int) -> String:
	return Phase.keys()[phase] if phase >= 0 and phase < Phase.size() else "UNKNOWN"
