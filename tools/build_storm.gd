extends SceneTree
## Builds the glyph storm config (task-030): res://resources/config/storm_config.tres. Idempotent; all tuning lives in
## StormConfig (scripts/rendering/storm_config.gd), change defaults there or set values here, then rebuild.
## Usage: godot --headless --max-fps 30 --path . -s tools/build_storm.gd

const PATH := "res://resources/config/storm_config.tres"


func _init() -> void:
	var config := StormConfig.new()
	var uid: int = ResourceLoader.get_resource_uid(PATH)
	var err: Error = ResourceSaver.save(config, PATH)
	if err != OK:
		push_error("Could not save %s: %s" % [PATH, error_string(err)])
		quit(1)
		return
	if uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(PATH, uid)
	print("Saved ", PATH)
	quit(0)
