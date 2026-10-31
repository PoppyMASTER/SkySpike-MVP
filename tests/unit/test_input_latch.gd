extends TestCase
## InputLatch : un appui n'est ni perdu ni compté deux fois, quel que soit le rapport images/ticks.


func test_a_press_between_ticks_is_consumed_exactly_once() -> void:
	var latch := InputLatch.new()
	latch.sample(0.0, false, false)
	latch.sample(0.0, true, false)
	latch.sample(0.0, false, false)   # images suivantes sans nouvel appui
	var first := latch.consume()
	var second := latch.consume()
	assert_true(first.jump_pressed, "le premier tick voit l'appui")
	assert_false(second.jump_pressed, "le second tick ne le revoit pas")


func test_press_survives_any_frame_tick_schedule() -> void:
	var rng := RandomNumberGenerator.new()   # hasard du TEST
	rng.seed = 5
	for trial in 200:
		var latch := InputLatch.new()
		var press_frame := rng.randi_range(0, 9)
		var seen := 0
		for frame in 12:
			latch.sample(1.0, frame == press_frame, false)
			for tick in rng.randi_range(0, 3):   # 0 à 3 ticks par image
				if latch.consume().jump_pressed:
					seen += 1
		for tick in 3:   # ticks restants après la dernière image
			if latch.consume().jump_pressed:
				seen += 1
		assert_eq(seen, 1, "essai %d : appui vu une fois" % trial)


func test_axis_is_held_and_clamped() -> void:
	var latch := InputLatch.new()
	latch.sample(0.7, false, false)
	assert_eq(latch.consume().move_axis, 0.7, "axe tenu")
	assert_eq(latch.consume().move_axis, 0.7, "axe toujours tenu au tick suivant")
	latch.sample(5.0, false, false)
	assert_eq(latch.consume().move_axis, 1.0, "borné à 1")
	latch.sample(-5.0, false, false)
	assert_eq(latch.consume().move_axis, -1.0, "borné à -1")


func test_clear_presses_keeps_the_axis() -> void:
	var latch := InputLatch.new()
	latch.sample(1.0, true, true)
	latch.clear_presses()
	var intent := latch.consume()
	assert_false(intent.jump_pressed or intent.receive_pressed, "appuis oubliés")
	assert_eq(intent.move_axis, 1.0, "axe conservé")


func test_actions_are_registered_once_with_keyboard_and_gamepad() -> void:
	InputMapper.register_actions()
	InputMapper.register_actions()
	for action: StringName in [InputMapper.MOVE_LEFT, InputMapper.MOVE_RIGHT, InputMapper.JUMP_ATTACK, InputMapper.RECEIVE_BLOCK_FEINT]:
		assert_true(InputMap.has_action(action), "action %s déclarée" % action)
	var jump_events := InputMap.action_get_events(InputMapper.JUMP_ATTACK)
	assert_eq(jump_events.size(), 2, "saut : une touche + un bouton, pas de doublon après deux appels")
	var has_space := false
	var has_pad := false
	for e in jump_events:
		if e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_SPACE:
			has_space = true
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_A:
			has_pad = true
	assert_true(has_space and has_pad, "Espace et bouton A")


func test_poll_reads_the_held_direction() -> void:
	InputMapper.register_actions()
	var latch := InputLatch.new()
	Input.action_press(InputMapper.MOVE_RIGHT)
	InputMapper.poll(latch)
	Input.action_release(InputMapper.MOVE_RIGHT)
	assert_eq(latch.consume().move_axis, 1.0, "droite tenue = axe 1")
	InputMapper.poll(latch)
	assert_eq(latch.consume().move_axis, 0.0, "relâchée = axe 0")
