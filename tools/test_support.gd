extends RefCounted
## Shared helpers for tools/test_*.gd. Keeps tests off the player's real save file.

const TEMP_PREFIX := "user://test_progress_"


## Points the main scene's SaveService at a temporary file (call before adding main to the tree).
static func isolate_save(main: Node, tag: String) -> String:
	var cfg := SaveConfig.new()
	cfg.save_path = "%s%s.tres" % [TEMP_PREFIX, tag]
	remove_file(cfg.save_path)
	main.get_node("SaveService").set("config", cfg)
	return cfg.save_path


## Deletes a temp save and its atomic-write temp sibling.
static func remove_file(path: String) -> void:
	for p in [path, path.get_basename() + ".tmp." + path.get_extension()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
