class_name FullscreenToggle
extends Node
## Switches between fullscreen and a centred window on the `toggle_fullscreen` InputMap action.
## Owns nothing else: scaling reacts to the resulting size_changed.

@export var config: DisplayConfig


func _ready() -> void:
	if config == null:
		config = DisplayConfig.new()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"toggle_fullscreen"):
		return
	get_viewport().set_input_as_handled()
	toggle()


## Flips between fullscreen and windowed.
func toggle() -> void:
	var window: Window = get_window()
	if window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		window.mode = Window.MODE_WINDOWED
		window.size = config.windowed_size
		var usable: Rect2i = DisplayServer.screen_get_usable_rect(window.current_screen)
		window.position = usable.position + (usable.size - window.size) / 2
	else:
		window.mode = Window.MODE_FULLSCREEN
