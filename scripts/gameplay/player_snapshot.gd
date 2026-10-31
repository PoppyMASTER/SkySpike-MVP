class_name PlayerSnapshot
extends RefCounted
## Copie en lecture seule d'un joueur à la fin d'un tick (pour le rendu, le debug, l'IA).

var slot := 0
var team := 0
var role: int = Enums.Role.ATTACKER
var character_id := ""
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var facing := 1
var grounded := true
var action: int = Enums.ActionState.FREE
var action_time := 0.0
## Instant idéal de l'action à fenêtre et durée utile (fin de fenêtre, ou durée de l'atterrissage) : 0 si sans objet.
## Lus par le rendu pour caler l'animation ; ils ne décident d'aucun contact.
var action_ideal := 0.0
var action_length := 0.0
## Charge du lancer de service (0 à 1), lue par le rendu pour l'animation de préparation.
var serve_charge := 0.0
## Intention de frappe du service (sol / flottant / smash) annoncée à l'ouverture de la fenêtre ; "" sinon.
var serve_intent := ""
## Instant d'état (s) où le contact de service est attendu (prévision de la simulation) ; 0 si sans objet.
var serve_expected := 0.0
## Dernière frappe de service : secondes écoulées (999 = aucune), type confirmé (ou intention si manquée), manquée ou non,
## temps d'état et instant idéal à la fermeture de la fenêtre. Lus par l'animation pour le suivi du geste et l'atterrissage.
var strike_age := 999.0
var strike_kind := ""
var strike_missed := false
var strike_window_time := 0.0
var strike_ideal := 0.0
## Zones de réception et de smash à la position actuelle (centre et rayon, en mètres).
var receive_center := Vector2.ZERO
var receive_radius := 0.0
var spike_center := Vector2.ZERO
var spike_radius := 0.0
## Zone dont la fenêtre est ouverte à cet instant ("" = aucune, sinon l'action ou "block").
var active_kind := ""
var active_center := Vector2.ZERO
var active_radius := 0.0


func fingerprint_parts() -> Array:
	return [position.x, position.y, velocity.x, velocity.y, action, action_time]
