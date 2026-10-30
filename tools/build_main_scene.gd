extends SceneTree
## Rebuilds res://main.tscn as an empty 3D root scene.
## Usage: godot --headless --path . -s tools/build_main_scene.gd

const SCENE_PATH := "res://main.tscn"


func _init() -> void:
	var root := Node3D.new()
	root.name = "Main"

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	root.free()
	if pack_err != OK:
		push_error("Failed to pack Main scene: %s" % error_string(pack_err))
		quit(1)
		return

	# project.godot points at the main scene by UID, so keep the existing one.
	var uid := ResourceLoader.get_resource_uid(SCENE_PATH)

	var save_err := ResourceSaver.save(packed, SCENE_PATH)
	if save_err != OK:
		push_error("Failed to save %s: %s" % [SCENE_PATH, error_string(save_err)])
		quit(1)
		return

	if uid != ResourceUID.INVALID_ID:
		var uid_err := ResourceSaver.set_uid(SCENE_PATH, uid)
		if uid_err != OK:
			push_error("Failed to set uid on %s: %s" % [SCENE_PATH, error_string(uid_err)])
			quit(1)
			return

	print("Saved %s (uid %s)" % [SCENE_PATH, ResourceUID.id_to_text(ResourceLoader.get_resource_uid(SCENE_PATH))])
	quit()
