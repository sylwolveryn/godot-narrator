extends SceneTree
## Builds the config .tres instances in res://resources/config/. Idempotent.
## Usage: godot --headless --path . -s tools/build_resources.gd

const DIR := "res://resources/config/"


func _init() -> void:
	var ok := true
	ok = _save(RunConfig.new(), "run_config.tres") and ok
	ok = _save(WorldConfig.new(), "world_config.tres") and ok
	ok = _save(AsciiConfig.new(), "ascii_config.tres") and ok

	var top_down := CameraViewConfig.new()
	ok = _save(top_down, "camera_top_down.tres") and ok

	var tilted := CameraViewConfig.new()
	tilted.orthographic = false
	tilted.pitch_degrees = -55.0
	tilted.distance = 14.0
	ok = _save(tilted, "camera_tilted.tres") and ok

	quit(0 if ok else 1)


func _save(res: Resource, file: String) -> bool:
	var path := DIR + file
	DirAccess.make_dir_recursive_absolute(DIR)
	# Reuse existing file uid when present so references stay valid.
	var uid := ResourceLoader.get_resource_uid(path)
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s: %s" % [path, error_string(err)])
		return false
	if uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(path, uid)
	print("Saved ", path)
	return true
