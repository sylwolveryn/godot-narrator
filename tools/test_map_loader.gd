extends SceneTree
## Headless test: MapLoader parses the M1 map and survives malformed input without crashing.
## Expected output includes logged ERROR/WARNING lines from the malformed cases.
## Usage: godot --headless --path . -s tools/test_map_loader.gd

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _new_loader() -> MapLoader:
	var loader := MapLoader.new()
	loader.legend = load("res://resources/config/map_legend.tres")
	loader.world_config = load("res://resources/config/world_config.tres")
	loader.auto_load = false
	root.add_child(loader)
	return loader


func _run() -> void:
	# 1. The real M1 map.
	var loader := _new_loader()
	var map := loader.load_file("res://data/maps/m1_awakening.txt")
	_check(map.errors.is_empty(), "M1 map has errors: %s" % [map.errors])
	_check(map.warnings.is_empty(), "M1 map has warnings: %s" % [map.warnings])
	_check(map.width == 40 and map.height == 23, "M1 map size %dx%d" % [map.width, map.height])
	_check(map.has_spawn and map.spawn_cell == Vector2i(20, 12), "M1 spawn %s" % [map.spawn_cell])
	loader.build(map)
	_check(loader.spawn_position.is_equal_approx(Vector3(20.5, 0.0, 12.5)), "spawn world pos %s" % [loader.spawn_position])
	_check(get_nodes_in_group("map_items").size() == 8, "expected 8 items, got %d" % get_nodes_in_group("map_items").size())
	_check(get_nodes_in_group("map_spikes").size() > 0, "no spikes built")
	_check(get_nodes_in_group("map_corrupt").size() > 0, "no corrupt cells built")
	var item: MapCell = get_nodes_in_group("map_items")[0]
	_check(item.cell_type == MapLegend.ITEM, "item cell_type")
	# Nothing lethal adjacent to the spawn.
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var t := map.type_at(map.spawn_cell + Vector2i(dx, dy))
			_check(t != MapLegend.SPIKES and t != MapLegend.CORRUPT, "hazard next to spawn")
	var wall_bodies := 0
	for c in loader.get_node("Cells").get_children():
		if c is StaticBody3D:
			wall_bodies += 1
	_check(wall_bodies > 0, "no wall bodies")
	loader.queue_free()

	# 2. Malformed inputs. Each must return a MapData and build without crashing.
	var cases: Dictionary = {
		"unknown_char": ["#####\n#.@x#\n#####\n", "warnings"],
		"missing_spawn": ["#####\n#...#\n#####\n", "errors"],
		"ragged_rows": ["#####\n#.@#\n#######\n", "warnings"],
		"empty": ["", "errors"],
		"only_void": ["   \n   \n", "errors"],
		"double_spawn": ["#####\n#@.@#\n#####\n", "warnings"],
	}
	for key: String in cases:
		var l := _new_loader()
		var m := l.parse_text(cases[key][0])
		var field: String = cases[key][1]
		var problems: PackedStringArray = m.get(field)
		_check(problems.size() > 0, "%s: expected %s" % [key, field])
		l.build(m)
		_check(true, key)
		l.queue_free()

	# Specific behaviours.
	var l2 := _new_loader()
	var no_spawn := l2.parse_text("#####\n#...#\n#####\n")
	_check(no_spawn.spawn_cell == Vector2i(1, 1) and no_spawn.has_spawn, "missing @ should fall back to first floor cell, got %s" % [no_spawn.spawn_cell])
	var unknown := l2.parse_text("#####\n#.@x#\n#####\n")
	_check(unknown.type_at(Vector2i(3, 1)) == MapLegend.FLOOR, "unknown char should become floor")
	var ragged := l2.parse_text("#####\n#.@#\n#######\n")
	_check(ragged.width == 7 and ragged.type_at(Vector2i(6, 1)) == MapLegend.VOID, "ragged rows should pad with void")

	# 3. Missing file.
	var missing := l2.load_file("res://data/maps/does_not_exist.txt")
	_check(missing.errors.size() == 1 and missing.is_empty(), "missing file should give one error and an empty map")
	l2.build(missing)
	_check(l2.get_node("Cells").get_child_count() == 0, "empty map should build no cells")
	l2.queue_free()

	if _failures.is_empty():
		print("PASS test_map_loader")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_map_loader")
		quit(1)
