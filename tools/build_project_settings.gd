extends SceneTree
## Writes display project settings into project.godot: fullscreen by default, a 1920x1080
## reference window size, and no engine stretch (the game scales its own pixel sizes from the
## viewport height, see DisplayConfig). Idempotent.
## Usage: godot --headless --path . -s tools/build_project_settings.gd

## Window.MODE_FULLSCREEN as stored in display/window/size/mode.
const MODE_FULLSCREEN := 3


func _init() -> void:
	var reference := DisplayConfig.new().reference_size
	ProjectSettings.set_setting("display/window/size/mode", MODE_FULLSCREEN)
	ProjectSettings.set_setting("display/window/size/viewport_width", reference.x)
	ProjectSettings.set_setting("display/window/size/viewport_height", reference.y)
	ProjectSettings.set_setting("display/window/size/resizable", true)
	ProjectSettings.set_setting("display/window/stretch/mode", "disabled")
	var err: int = ProjectSettings.save()
	if err != OK:
		push_error("Failed to save project.godot: %s" % error_string(err))
	else:
		print("Saved display settings")
	quit(0 if err == OK else 1)
