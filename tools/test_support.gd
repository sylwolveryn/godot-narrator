extends RefCounted
## Shared helpers for tools/test_*.gd. Keeps tests off the player's real save file.

const TEMP_PREFIX := "user://test_progress_"


## Points the main scene's SaveService at a temporary file (call before adding main to the tree).
static func isolate_save(main: Node, tag: String) -> String:
	var cfg := SaveConfig.new()
	cfg.save_path = "%s%s.tres" % [TEMP_PREFIX, tag]
	remove_file(cfg.save_path)
	main.get_node("SaveService").set("config", cfg)
	isolate_data(main, tag)
	return cfg.save_path


## Keeps tests off the real SpacetimeDB (no server calls) and off the real narration override folder and missing log.
static func isolate_data(main: Node, tag: String) -> void:
	var db: Node = main.get_node_or_null("GameDatabase")
	if db != null:
		var db_cfg := DbConfig.new()
		db_cfg.enabled = false
		db.set("config", db_cfg)
	var library: Node = main.get_node_or_null("NarrationLibrary")
	if library != null:
		var lib_cfg := NarrationLibraryConfig.new()
		lib_cfg.override_root = ProjectSettings.globalize_path("user://test_override_%s" % tag)
		library.set("config", lib_cfg)


## Deletes a temp save and its atomic-write temp sibling.
static func remove_file(path: String) -> void:
	for p in [path, path.get_basename() + ".tmp." + path.get_extension()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
