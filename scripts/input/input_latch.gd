class_name InputLatch
extends RefCounted
## Fait le pont entre les images (60, 144 i/s…) et les ticks (120/s). L'axe est l'état tenu
## à l'image la plus récente ; un appui est mémorisé jusqu'au prochain tick, qui le consomme
## une seule fois. Aucun appui n'est perdu ni compté deux fois, quel que soit le FPS.

var _axis := 0.0
var _jump := false
var _receive := false


## Appelé à chaque image avec l'état des touches.
func sample(axis: float, jump_just_pressed: bool, receive_just_pressed: bool) -> void:
	_axis = clampf(axis, -1.0, 1.0)
	_jump = _jump or jump_just_pressed
	_receive = _receive or receive_just_pressed


## Appelé à chaque tick : renvoie l'intention et efface les appuis.
func consume() -> PlayerIntent:
	var intent := PlayerIntent.make(_axis, _jump, _receive)
	_jump = false
	_receive = false
	return intent


## Oublie les appuis en attente (pause, rechargement), garde l'axe tenu.
func clear_presses() -> void:
	_jump = false
	_receive = false
