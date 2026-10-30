extends SceneTree
## Writes the movement and toggle_fullscreen InputMap actions into project.godot ([input]) and removes the legacy
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
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	_set_action("move_pointer", [click])
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


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e


func _button(index: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = index
	return e
