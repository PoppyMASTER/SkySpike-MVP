class_name Enums
extends RefCounted
## Énumérations partagées par toutes les couches. Aucune chaîne magique pour les états.

enum Role { ATTACKER, SETTER, DEFENDER }

## États d'action d'un joueur (J2 : sous-ensemble de la machine complète du J3).
enum ActionState { FREE, RECEIVE, AIR, SPIKE, RECOVER }

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
