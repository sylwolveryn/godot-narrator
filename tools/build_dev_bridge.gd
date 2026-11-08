extends SceneTree
## Registers the DevBridge autoload (scripts/core/dev_bridge.gd): god's live controls for a running game (the
## addons/debug_menu FPS / frametime / CPU / GPU overlay, reveal the current map). Replaces the old PerfOverlay entry.
## The Debug Menu addon's own editor plugin is NOT enabled: DevBridge instances the addon scene itself, lazily.
## Idempotent. Usage: godot --headless --path . -s tools/build_dev_bridge.gd

const KEY := "autoload/DevBridge"
const VALUE := "*res://scripts/core/dev_bridge.gd"
const OLD_KEY := "autoload/PerfOverlay"


func _init() -> void:
	if ProjectSettings.has_setting(OLD_KEY):
		ProjectSettings.set_setting(OLD_KEY, null)
	ProjectSettings.set_setting(KEY, VALUE)
	var err: int = ProjectSettings.save()
	if err != OK:
		push_error("Failed to save project.godot: %s" % error_string(err))
	else:
		print("Registered DevBridge autoload")
	quit(0 if err == OK else 1)
