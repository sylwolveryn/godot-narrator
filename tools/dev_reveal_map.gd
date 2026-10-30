extends SceneTree
## Dev tool (task-020.03): marks every non-void cell of the M1 map as revealed in the saved progress.
## Loads and writes through the game's own SaveService, so the file stays valid. Refuses to touch a
## missing or unsafe save (loading those would silently reset it to fresh progress).
## Usage: godot --headless --path . -s tools/dev_reveal_map.gd [-- <save_path>]
## Without a path the save from resources/config/save_config.tres is used.

const MAP_PATH := "res://data/maps/m1_awakening.txt"
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
	if args.size() > 0:
		cfg.save_path = args[0]
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
	var map: MapData = loader.call("parse_text", FileAccess.get_file_as_string(MAP_PATH))
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
	progress.revealed_cells[&"m1_awakening"] = cells
	svc.call("save_progress")
	print("PASS dev_reveal_map: revealed %d cells in %s" % [cells.size(), cfg.save_path])
	loader.free()
	svc.free()
	quit(0)
