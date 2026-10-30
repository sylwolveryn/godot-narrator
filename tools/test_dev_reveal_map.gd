extends SceneTree
## Headless test of tools/dev_reveal_map.gd (task-020.03) using a temp save under user://.
## Usage: godot --headless --path . -s tools/test_dev_reveal_map.gd

const Support := preload("res://tools/test_support.gd")
const PATH := "user://test_progress_dev_reveal.tres"
const MAP_ID := &"m1_awakening"

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _service() -> Node:
	var cfg := SaveConfig.new()
	cfg.save_path = PATH
	var svc: Node = load("res://scripts/core/save_service.gd").new()
	svc.set("config", cfg)
	svc.call("load_progress")
	return svc


func _run_tool() -> int:
	var out: Array = []
	return OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "tools/dev_reveal_map.gd", "--", ProjectSettings.globalize_path(PATH)], out, true)


func _run() -> void:
	Support.remove_file(PATH)

	# Missing save: tool must fail and not create the file.
	_check(_run_tool() != 0, "tool should fail without a save")
	_check(not FileAccess.file_exists(PATH), "tool must not create a missing save")

	# Seeded save: other fields preserved, every non-void cell revealed.
	var svc := _service()
	var p: PersistentProgress = svc.get("progress")
	p.identity_glyph = "Q"
	p.run_count = 3
	p.death_count = 5
	p.heard_beats = PackedStringArray(["wake_first"])
	p.revealed_cells = {MAP_ID: PackedVector2Array([Vector2(1, 1)])}
	svc.call("save_progress")
	svc.free()
	_check(_run_tool() == 0, "tool should succeed with a save")

	var after := _service()
	var q: PersistentProgress = after.get("progress")
	_check(q.identity_glyph == "Q" and q.run_count == 3 and q.death_count == 5, "scalar fields must be preserved")
	_check(q.heard_beats == PackedStringArray(["wake_first"]), "heard_beats must be preserved")
	var cells: PackedVector2Array = q.revealed_cells.get(MAP_ID, PackedVector2Array())
	var loader: Node = load("res://scripts/world/map_loader.gd").new()
	loader.set("legend", load("res://resources/config/map_legend.tres"))
	var map: MapData = loader.call("parse_text", FileAccess.get_file_as_string("res://data/maps/m1_awakening.txt"))
	var expected := 0
	for y in map.height:
		for x in map.width:
			if map.type_at(Vector2i(x, y)) != MapLegend.VOID:
				expected += 1
				_check(cells.has(Vector2(x, y)), "cell %d,%d not revealed" % [x, y])
	_check(expected > 0 and cells.size() == expected, "expected %d revealed cells, got %d" % [expected, cells.size()])
	loader.free()
	after.free()

	# Garbage save is refused and left untouched.
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("garbage")
	f.close()
	_check(_run_tool() != 0, "tool should refuse a corrupt save")
	_check(FileAccess.get_file_as_string(PATH) == "garbage", "corrupt save must be left untouched")

	Support.remove_file(PATH)
	if _failures.is_empty():
		print("PASS test_dev_reveal_map")
		quit(0)
	else:
		for m in _failures:
			printerr("FAIL: ", m)
		print("FAIL test_dev_reveal_map")
		quit(1)
