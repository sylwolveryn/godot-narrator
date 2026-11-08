extends SceneTree
## Dev tool (task-020.03): marks every non-void cell of a map (default M1) as revealed in the saved progress.
## god uses it only while the game is NOT running; a running game is revealed live through DevBridge instead
## (the game would otherwise overwrite the file with its own in-memory progress).
## Loads and writes through the game's own SaveService, so the file stays valid. Refuses to touch a
## missing or unsafe save (loading those would silently reset it to fresh progress).
## Usage: godot --headless --path . -s tools/dev_reveal_map.gd [-- [<save_path>] [--map=<name or path>]]
## Without a path the save from resources/config/save_config.tres is used; --map works like the game's (MapLoader).

const MAP_PATH := "res://data/maps/m1_awakening.txt"
const MAPS_DIR := "res://data/maps/"
const LEGEND_PATH := "res://resources/config/map_legend.tres"
const SAVE_CONFIG_PATH := "res://resources/config/save_config.tres"


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _fail(msg: String) -> void:
	printerr("FAIL dev_reveal_map: ", msg)
	quit(1)


func _run() -> void:
	var cfg: SaveConfig = (load(SAVE_CONFIG_PATH) as SaveConfig).duplicate()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg in args:
		if not arg.begins_with(MapLoader.MAP_ARG_PREFIX):
			cfg.save_path = arg
	var map_path: String = MapLoader.map_path_from_args(args, MAP_PATH, MAPS_DIR)
	if not FileAccess.file_exists(map_path):
		_fail("no map at %s" % map_path)
		return
	var map_id := StringName(map_path.get_file().get_basename())
	if not FileAccess.file_exists(cfg.save_path):
		_fail("no save at %s" % cfg.save_path)
		return
	var svc: Node = load("res://scripts/core/save_service.gd").new()
	svc.set("config", cfg)
	if not svc.call("_is_safe_text", FileAccess.get_file_as_string(cfg.save_path)):
		svc.free()
		_fail("save at %s is corrupt or not a progress file" % cfg.save_path)
		return
	svc.call("load_progress")

	var loader: Node = load("res://scripts/world/map_loader.gd").new()
	loader.set("legend", load(LEGEND_PATH))
	var map: MapData = loader.call("parse_text", FileAccess.get_file_as_string(map_path))
	var cells := PackedVector2Array()
	for y in map.height:
		for x in map.width:
			if map.type_at(Vector2i(x, y)) != MapLegend.VOID:
				cells.append(Vector2(x, y))
	if cells.is_empty():
		loader.free()
		svc.free()
		_fail("map has no cells")
		return
	var progress: PersistentProgress = svc.get("progress")
	progress.revealed_cells[map_id] = cells
	svc.call("save_progress")
	print("PASS dev_reveal_map: revealed %d cells of %s in %s" % [cells.size(), map_id, cfg.save_path])
	loader.free()
	svc.free()
	quit(0)
