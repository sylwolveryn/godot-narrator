class_name InputDiscovery
extends Node
## Watches raw input events and decides which supported scheme the player is using.
## The first supported input becomes the active scheme; a different supported device
## used later switches it. Events that match no movement action change nothing.
## Emits SignalBus.input_scheme_discovered upward; it never moves anything itself.

@export var config: PlayerConfig

var scheme: StringName = InputScheme.NONE


func _ready() -> void:
	if config == null:
		config = PlayerConfig.new()


func _input(event: InputEvent) -> void:
	var found: StringName = classify(event)
	if found == InputScheme.NONE or found == scheme:
		return
	scheme = found
	SignalBus.input_scheme_discovered.emit(scheme)


## Returns the scheme an event belongs to, or NONE when it does not trigger any movement action.
func classify(event: InputEvent) -> StringName:
	if event is InputEventMouseButton:
		return InputScheme.MOUSE if event.is_action_pressed(config.action_pointer) else InputScheme.NONE
	var device: StringName = InputScheme.NONE
	if event is InputEventKey:
		device = InputScheme.KEYBOARD
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		device = InputScheme.GAMEPAD
	if device == InputScheme.NONE:
		return InputScheme.NONE
	for action: StringName in [config.action_left, config.action_right, config.action_up, config.action_down]:
		if event.is_action_pressed(action):
			return device
	return InputScheme.NONE
