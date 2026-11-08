extends SceneTree
## Writes the movement, sprint, menu, intro_skip, camera_* and toggle_fullscreen InputMap actions into project.godot ([input]) and removes the legacy
## prototype `transform` action. Idempotent.
## Usage: godot --headless --path . -s tools/build_input_map.gd

const DEADZONE := 0.25
## Event device id meaning "any device".
const ALL_DEVICES := -1


func _init() -> void:
	ProjectSettings.set_setting("input/transform", null)
	_set_action("move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0), _button(JOY_BUTTON_DPAD_LEFT)])
	_set_action("move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0), _button(JOY_BUTTON_DPAD_RIGHT)])
	_set_action("move_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0), _button(JOY_BUTTON_DPAD_UP)])
	_set_action("move_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0), _button(JOY_BUTTON_DPAD_DOWN)])
	# Sprint (task-063): unlocked after the first death; held to run.
	_set_action("sprint", [_key(KEY_SHIFT), _button(JOY_BUTTON_LEFT_STICK), _button(JOY_BUTTON_RIGHT_SHOULDER)])
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	_set_action("move_pointer", [click])
	# In-world menu (task-018): open/close, move the selection (same keys as moving), confirm. The pointer clicks items
	# through the menu view, so left click is not bound here.
	# The right mouse button is the camera drag (task-051), so the menu opens with Tab / Start only.
	_set_action("menu_toggle", [_key(KEY_TAB), _button(JOY_BUTTON_START)])
	_set_action("menu_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0), _button(JOY_BUTTON_DPAD_UP)])
	_set_action("menu_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0), _button(JOY_BUTTON_DPAD_DOWN)])
	_set_action("menu_confirm", [_key(KEY_ENTER), _key(KEY_KP_ENTER), _key(KEY_SPACE), _button(JOY_BUTTON_A)])
	# Intro skip (task-050): swallowed by IntroSequence while the intro is up, so it never leaks into the game.
	_set_action("intro_skip", [_key(KEY_ESCAPE), _key(KEY_SPACE), _mouse(MOUSE_BUTTON_LEFT), _mouse(MOUSE_BUTTON_RIGHT),
		_button(JOY_BUTTON_A), _button(JOY_BUTTON_START)])
	# Interact (task-072): only takes over Space / left click while an interactable is in reach (Interactables).
	_set_action("interact", [_key(KEY_SPACE), _mouse(MOUSE_BUTTON_LEFT), _button(JOY_BUTTON_X)])
	# Camera rotation and zoom (task-051).
	_set_action("camera_rotate_left", [_key(KEY_Q)])
	_set_action("camera_rotate_right", [_key(KEY_E)])
	_set_action("camera_drag", [_mouse(MOUSE_BUTTON_RIGHT)])
	_set_action("camera_zoom_in", [_mouse(MOUSE_BUTTON_WHEEL_UP), _key(KEY_PAGEUP)])
	_set_action("camera_zoom_out", [_mouse(MOUSE_BUTTON_WHEEL_DOWN), _key(KEY_PAGEDOWN)])
	var alt_enter := _key(KEY_ENTER)
	alt_enter.alt_pressed = true
	_set_action("toggle_fullscreen", [_key(KEY_F11), alt_enter])
	var err: int = ProjectSettings.save()
	if err != OK:
		push_error("Failed to save project.godot: %s" % error_string(err))
	else:
		print("Saved input map")
	quit(0 if err == OK else 1)


func _set_action(action: String, events: Array) -> void:
	for e: InputEvent in events:
		e.device = ALL_DEVICES
	ProjectSettings.set_setting("input/" + action, {"deadzone": DEADZONE, "events": events})


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _mouse(index: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = index
	return e


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e


func _button(index: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = index
	return e
