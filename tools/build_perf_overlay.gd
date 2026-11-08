extends SceneTree
## Registers the PerfOverlay autoload (scripts/ui/perf_overlay.gd), which shows the vendored
## addons/debug_menu FPS / frametime / CPU / GPU graphs when god switches it on. The addon's own
## editor plugin is NOT enabled: PerfOverlay instances the addon scene itself, lazily. Idempotent.
## Usage: godot --headless --path . -s tools/build_perf_overlay.gd

const KEY := "autoload/PerfOverlay"
const VALUE := "*res://scripts/ui/perf_overlay.gd"


func _init() -> void:
	ProjectSettings.set_setting(KEY, VALUE)
	var err: int = ProjectSettings.save()
	if err != OK:
		push_error("Failed to save project.godot: %s" % error_string(err))
	else:
		print("Registered PerfOverlay autoload")
	quit(0 if err == OK else 1)
