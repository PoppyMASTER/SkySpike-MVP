class_name InputMapper
extends RefCounted
## Touches PROVISOIRES (décision J2 du 31/10/2026, à valider au ressenti par Djebril) et lecture
## des périphériques. Les actions sont déclarées ici, dans le code : project.godot reste intact.
##
## | Action              | Clavier       | Manette        |
## | move_left/right     | ← → ou Q, A, D | stick gauche   |
## | jump_attack         | Espace        | A              |
## | receive_block_feint | J             | X              |
## (set_action K / B et serve_action L / Y arrivent au J3.)

const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const JUMP_ATTACK := &"jump_attack"
const RECEIVE_BLOCK_FEINT := &"receive_block_feint"
const STICK_DEADZONE := 0.25


## Déclare les actions (sans effet si déjà faites).
static func register_actions() -> void:
	_add(MOVE_LEFT, [_key(KEY_LEFT), _key(KEY_A), _key(KEY_Q), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add(MOVE_RIGHT, [_key(KEY_RIGHT), _key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add(JUMP_ATTACK, [_key(KEY_SPACE), _button(JOY_BUTTON_A)])
	_add(RECEIVE_BLOCK_FEINT, [_key(KEY_J), _button(JOY_BUTTON_X)])


## Lit les touches et alimente le tampon de l'image courante.
static func poll(latch: InputLatch) -> void:
	latch.sample(Input.get_axis(MOVE_LEFT, MOVE_RIGHT),
		Input.is_action_just_pressed(JUMP_ATTACK), Input.is_action_just_pressed(RECEIVE_BLOCK_FEINT))


static func _add(action: StringName, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, STICK_DEADZONE)
	for event in events:
		InputMap.action_add_event(action, event)


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _button(index: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = index
	return e


static func _axis(axis: JoyAxis, direction: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = direction
	return e
