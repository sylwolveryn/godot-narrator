extends SceneTree
## Headless test (task-036): light occlusion on the map grid. A wall between a light and a cell blocks it, an open
## line does not, light goes round a corner only partly, items do not block, and GlyphVisibilityMap writes the values
## into the shader textures (floor region, wall region, blending). Also times the player-light computation.
## Usage: godot --headless --path . --max-fps 30 -s tools/test_light_occlusion.gd

const PENUMBRA := 0.35
const MAP_TEXT := """
#########
#...#...#
#...#...#
#.......#
#...#.*.#
#########
"""

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _parse(text: String) -> MapData:
	var rows: PackedStringArray = text.strip_edges().split("\n")
	var map := MapData.new()
	map.height = rows.size()
	map.width = rows[0].length()
	for row in rows:
		for ch in row:
			map.types.append(MapLegend.WALL if ch == "#" else (MapLegend.ITEM if ch == "*" else MapLegend.FLOOR))
	return map


func _run() -> void:
	var map: MapData = _parse(MAP_TEXT)
	_check(map.type_at(Vector2i(4, 1)) == MapLegend.WALL and map.type_at(Vector2i(6, 4)) == MapLegend.ITEM, "test map layout")

	# Light in the left room (1,1): the right room behind the wall x=4 is dark, the left room is lit.
	var origin := Vector2i(1, 1)
	_check(GlyphLightOcclusion.visibility(map, origin, Vector2i(2, 2), PENUMBRA) == 1.0, "open line inside the room should be fully visible")
	_check(GlyphLightOcclusion.visibility(map, origin, Vector2i(1, 1), PENUMBRA) == 1.0, "own cell visible")
	_check(GlyphLightOcclusion.visibility(map, origin, Vector2i(6, 1), PENUMBRA) == 0.0, "a wall between light and cell must block it")
	_check(GlyphLightOcclusion.visibility(map, origin, Vector2i(5, 2), PENUMBRA) == 0.0, "cell right behind the wall is dark")
	# Through the door gap (4,3): the cell in line with it is visible, the one just behind the wall next to it is not.
	_check(GlyphLightOcclusion.visibility(map, Vector2i(2, 3), Vector2i(6, 3), PENUMBRA) == 1.0, "straight through the door gap is lit")
	_check(GlyphLightOcclusion.visibility(map, Vector2i(2, 3), Vector2i(6, 1), PENUMBRA) < 1.0, "a cell behind the wall next to the door is shadowed")
	var corner: float = GlyphLightOcclusion.visibility(map, Vector2i(3, 3), Vector2i(5, 2), PENUMBRA)
	_check(corner > 0.0 and corner < 1.0, "a cell at the door edge gets a soft shadow, got %f" % corner)
	# Items do not block light.
	_check(GlyphLightOcclusion.visibility(map, Vector2i(5, 3), Vector2i(7, 4), PENUMBRA) == 1.0, "an item must not block")
	_check(GlyphLightOcclusion.visibility(map, Vector2i(5, 4), Vector2i(7, 4), PENUMBRA) == 1.0, "light passes the item cell")

	# compute(): wall cells never appear, hidden cells are left out, radius is respected.
	var field: Dictionary[Vector2i, float] = GlyphLightOcclusion.compute(map, origin, 8.0, PENUMBRA)
	_check(field.has(Vector2i(3, 2)) and field[Vector2i(3, 2)] == 1.0, "left room cell in the field")
	_check(not field.has(Vector2i(4, 1)), "wall cells are not part of the field")
	_check(not field.has(Vector2i(6, 1)), "cell behind the wall is not part of the field")
	var small: Dictionary[Vector2i, float] = GlyphLightOcclusion.compute(map, Vector2i(2, 3), 1.5, PENUMBRA)
	_check(not small.has(Vector2i(5, 3)), "cell beyond the radius is not part of the field")

	# GlyphVisibilityMap: assign writes the floor texel and the wall texel; blend glides.
	var vm := GlyphVisibilityMap.new()
	vm.setup(map, 0.2)
	vm.assign(0, field)
	var lit_floor: Color = vm.texel(0, Vector2i(3, 2), false)
	_check(is_equal_approx(lit_floor.r, 1.0), "floor texel r = slot 0 visibility, got %s" % lit_floor)
	_check(is_equal_approx(vm.texel(0, Vector2i(6, 1), false).r, 0.0), "dark cell texel is 0")
	_check(is_equal_approx(vm.texel(0, Vector2i(4, 1), false).r, 0.0), "wall cell has no floor-region value")
	_check(vm.texel(0, Vector2i(4, 1), true).r > 0.9, "wall cell borders a lit cell: wall-region texel lit")
	_check(is_equal_approx(vm.texel(0, Vector2i(0, 0), true).r, 0.0), "corner wall without lit neighbours stays dark")
	vm.assign(5, field)
	_check(is_equal_approx(vm.texel(1, Vector2i(3, 2), false).g, 1.0), "slot 5 goes to texture b, channel g")
	vm.assign(5, {})
	_check(is_equal_approx(vm.texel(1, Vector2i(3, 2), false).g, 0.0), "clearing a slot zeroes its channel")
	var moved: Dictionary[Vector2i, float] = GlyphLightOcclusion.compute(map, Vector2i(6, 2), 8.0, PENUMBRA)
	vm.blend(0, moved)
	_check(vm.is_blending(), "blend starts")
	vm.step(0.1)
	var mid: float = vm.value_at(0, Vector2i(3, 2))
	_check(mid > 0.0 and mid < 1.0, "blend is halfway after half the time, got %f" % mid)
	vm.step(0.2)
	_check(not vm.is_blending() and is_equal_approx(vm.value_at(0, Vector2i(3, 2)), moved.get(Vector2i(3, 2), 0.0)), "blend finishes")

	# Real map: timing of the player-light computation (radius from the config).
	var loader := MapLoader.new()
	loader.legend = load("res://resources/config/map_legend.tres")
	loader.world_config = load("res://resources/config/world_config.tres")
	loader.auto_load = false
	root.add_child(loader)
	var m1: MapData = loader.load_file("res://data/maps/m1_awakening.txt")
	var look: GlyphWorldConfig = load("res://resources/config/glyph_world_config.tres")
	var t0: int = Time.get_ticks_usec()
	var runs: int = 20
	var total: int = 0
	for i in runs:
		total += GlyphLightOcclusion.compute(m1, Vector2i(14 + i % 5, 12), look.player_light_radius, look.occlusion_penumbra).size()
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0 / runs
	print("player light occlusion on M1: %.2f ms per cell change (avg %d lit cells)" % [ms, total / runs])
	var spawn_field: Dictionary[Vector2i, float] = GlyphLightOcclusion.compute(m1, Vector2i(20, 12), look.player_light_radius, look.occlusion_penumbra)
	_check(not spawn_field.has(Vector2i(20, 18)), "M1: south room behind the wall (y=15) is not lit from the spawn")
	_check(spawn_field.has(Vector2i(20, 11)), "M1: cell next to the spawn is lit")

	for f in _failures:
		printerr("FAIL: ", f)
	print("PASS test_light_occlusion" if _failures.is_empty() else "FAIL test_light_occlusion")
	quit(0 if _failures.is_empty() else 1)
