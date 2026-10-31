class_name AnimationSetDefinition
extends RefCounted
## Ensemble d'animations d'un perso : un jeu standard + remplacements par action.
## J1 : seule la structure est chargée ; l'existence des clips est vérifiée au J4.

const STANDARD_SET := "standard_v1"
const ACTIONS: Array[String] = [
	"idle", "run", "jump", "land", "receive", "set", "spike", "serve", "serve_prep", "serve_toss", "block", "feint",
]

var default_set := STANDARD_SET
var overrides: Dictionary = {}   # action (String) -> clip id (String)


func clip_for(action: String) -> String:
	return overrides.get(action, "")


func has_override(action: String) -> bool:
	return overrides.has(action)
