extends SceneTree
## Headless test of the merged multi-cell props (task-058) and the arena map (task-059): rectangle merging (1x1, 2x1,
## 1x2, 2x2, 3x2, L-shape, separate groups, mixed types), one LargeObjectView piece per merged object scaled to its
## footprint, the collision box (a body cannot walk through), line of sight / light blocking, the `--map=` argument
## helper (task-060), and the arena map loading and playing in the main scene with reveal-aware gargoyles.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_large_objects.gd

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "large_objects"
const LEGEND := "res://resources/config/map_legend.tres"
const WORLD := "res://resources/config/world_config.tres"
const PLAYER_CFG := "res://resources/config/player_config.tres"
const ARENA := "res://data/maps/m2_arena.txt"
const GARGOYLE: StringName = &"gargoyle"
const OTHER: StringName = &"test_other"
const PHASE_PLAYING := 1
## MapReveal.CellState values (the test cannot name MapReveal: it depends on the SignalBus autoload).
const CELL_HIDDEN := 0
const CELL_SEEN := 2
const VIEW_SCRIPT := "res://scripts/rendering/large_object_view.gd"

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _run() -> void:
	_check_merging()
	_check_args()
	await _check_view_and_collision()
	await _check_statues()
	await _check_arena()
	if _failures.is_empty():
		print("PASS test_large_objects")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_large_objects")
		quit(1)


## The shipped legend plus a second (test-only) large type `H`, so mixed types can be checked.
func _legend() -> MapLegend:
	var legend: MapLegend = (load(LEGEND) as MapLegend).duplicate()
	var other := LargeObjectDef.new()
	other.type = OTHER
	other.character = "Q"  # task-075: H is the hunter now
	other.art_lines = PackedStringArray(["[H]"])
	legend.large_objects = legend.large_objects.duplicate()
	legend.large_objects[OTHER] = other
	return legend


func _loader(legend: MapLegend) -> MapLoader:
	var loader := MapLoader.new()
	loader.legend = legend
	loader.world_config = load(WORLD)
	loader.auto_load = false
	loader.use_cmdline_map = false
	return loader


## Parses `text` (a spawn row is appended below it, so coordinates stay as written) and returns "type x y w h" strings.
func _rects(loader: MapLoader, text: String) -> PackedStringArray:
	var width: int = 0
	for line in text.split("\n"):
		width = maxi(width, line.length())
	var map: MapData = loader.parse_text(text + "\n" + "@".rpad(width, "."))
	var out := PackedStringArray()
	for p in map.large_objects:
		out.append("%s %d %d %d %d" % [p.type, p.rect.position.x, p.rect.position.y, p.rect.size.x, p.rect.size.y])
	return out


func _expect(loader: MapLoader, text: String, expected: Array[String], what: String) -> void:
	var got: PackedStringArray = _rects(loader, text)
	_check(got == PackedStringArray(expected), "%s: expected %s, got %s" % [what, expected, got])


func _check_merging() -> void:
	var legend: MapLegend = _legend()
	_check(legend.type_for("G") == GARGOYLE, "legend maps G to the gargoyle type")
	_check(legend.is_large(GARGOYLE) and not legend.is_large(MapLegend.WALL), "is_large")
	var loader: MapLoader = _loader(legend)
	root.add_child(loader)
	_expect(loader, "G", ["gargoyle 0 0 1 1"], "1x1")
	_expect(loader, ".GG.", ["gargoyle 1 0 2 1"], "2x1")
	_expect(loader, "G\nG", ["gargoyle 0 0 1 2"], "1x2")
	_expect(loader, "GG\nGG", ["gargoyle 0 0 2 2"], "2x2")
	_expect(loader, "GGG\nGGG", ["gargoyle 0 0 3 2"], "3x2")
	_expect(loader, "GG\nG.", ["gargoyle 0 0 2 1", "gargoyle 0 1 1 1"], "L-shape")
	_expect(loader, ".G\nGG", ["gargoyle 1 0 1 2", "gargoyle 0 1 1 1"], "mirrored L-shape (down first, then the rest)")
	_expect(loader, "GG.GG\n.....\nG....", ["gargoyle 0 0 2 1", "gargoyle 3 0 2 1", "gargoyle 0 2 1 1"], "separate groups")
	_expect(loader, "GQ\nGQ", ["gargoyle 0 0 1 2", "test_other 1 0 1 2"], "mixed types do not merge")
	_expect(loader, "GGQ", ["gargoyle 0 0 2 1", "test_other 2 0 1 1"], "mixed run")
	_expect(loader, "GG.\nGGG", ["gargoyle 0 0 2 2", "gargoyle 2 1 1 1"], "2x2 plus a tail")
	var map: MapData = loader.parse_text("#GG.\n#GG@")
	_check(map.warnings.is_empty() and map.errors.is_empty(), "G parses without warnings: %s %s" % [map.warnings, map.errors])
	_check(map.type_at(Vector2i(1, 0)) == GARGOYLE, "footprint cells keep the gargoyle type")
	_check(map.large_object_at(Vector2i(2, 1)) != null and map.large_object_at(Vector2i(3, 1)) == null, "large_object_at")
	# Line of sight and light: the footprint hides what is behind it but is itself seen.
	var sight: MapData = loader.parse_text("@.G..\n.....")
	var blockers: Array[StringName] = [MapLegend.WALL]
	blockers.append_array(legend.sight_blocking_types())
	_check(SightLine.can_see(sight, Vector2i(0, 0), Vector2i(2, 0), blockers, 0.0), "the gargoyle itself is seen")
	_check(not SightLine.can_see(sight, Vector2i(0, 0), Vector2i(4, 0), blockers, 0.0), "the gargoyle hides the cell behind it")
	_check(GlyphLightOcclusion.blocks(sight, Vector2i(2, 0)), "the gargoyle blocks light")
	loader.queue_free()


func _check_args() -> void:
	var dir := "res://data/maps/"
	var fallback := "res://data/maps/m1_awakening.txt"
	_check(MapLoader.map_path_from_args(PackedStringArray(), fallback, dir) == fallback, "no args -> fallback")
	_check(MapLoader.map_path_from_args(PackedStringArray(["--other=1"]), fallback, dir) == fallback, "unrelated args -> fallback")
	_check(MapLoader.map_path_from_args(PackedStringArray(["--map="]), fallback, dir) == fallback, "empty value -> fallback")
	_check(MapLoader.map_path_from_args(PackedStringArray(["--map=m2_arena"]), fallback, dir) == ARENA, "bare name")
	_check(MapLoader.map_path_from_args(PackedStringArray(["--map=m2_arena.txt"]), fallback, dir) == ARENA, "file name")
	_check(MapLoader.map_path_from_args(PackedStringArray(["--map=res://data/maps/m2_arena.txt"]), fallback, dir) == ARENA, "res path")
	_check(MapLoader.map_path_from_args(PackedStringArray(["--map=data\\maps\\m2_arena.txt"]), fallback, dir) == ARENA, "relative windows path")
	_check(MapLoader.map_path_from_args(PackedStringArray(["--map=m1_awakening", "--map=m2_arena"]), fallback, dir) == ARENA, "last --map wins")


## Flat-art pieces (the fallback when a def has no baked views): the gargoyle def without its views.
func _check_view_and_collision() -> void:
	var legend: MapLegend = _legend()
	var flat: LargeObjectDef = (legend.large_def(GARGOYLE) as LargeObjectDef).duplicate()
	flat.views = null
	flat.views_small = null
	flat.basin = false
	legend.large_objects[GARGOYLE] = flat
	var loader: MapLoader = _loader(legend)
	root.add_child(loader)
	var view: Node3D = load(VIEW_SCRIPT).new()
	view.set("map_loader", loader)
	root.add_child(view)
	var text := "##########\n#G..GG...#\n#........#\n#GG.GGG..#\n#GG.GGG.@#\n#........#\n##########"
	loader.build(loader.parse_text(text))
	await process_frame
	await process_frame
	var map: MapData = loader.data
	_check(map.large_objects.size() == 4, "4 merged gargoyles, got %d" % map.large_objects.size())
	_check(view.call("piece_count") == map.large_objects.size(), "one view piece per merged object (%d vs %d)" % [view.call("piece_count"), map.large_objects.size()])
	var def: LargeObjectDef = legend.large_def(GARGOYLE)
	var cell: float = loader.world_config.cell_size
	var bodies: Array[Node] = loader.get_tree().get_nodes_in_group(&"map_large_objects")
	_check(bodies.size() == map.large_objects.size(), "one collision body per merged object, got %d" % bodies.size())
	for i in view.call("piece_count"):
		var p: LargeObjectPlacement = view.call("piece_placement", i)
		var node: Node3D = view.call("piece_node", i)
		_check(node.scale.is_equal_approx(Vector3(p.rect.size.x, p.rect.size.y, 1.0)), "piece %s scale %s" % [p.rect, node.scale])
		_check(is_equal_approx(view.call("piece_art_width", i), p.rect.size.x * cell * def.art_width_ratio), "piece %s art width" % p.rect)
		var centre: Vector3 = loader.rect_to_world(p.rect)
		_check(is_equal_approx(node.position.x, centre.x) and is_equal_approx(node.position.z, centre.z), "piece %s centred" % p.rect)
		_check(view.call("piece_labels", i).size() == def.layers().size(), "piece %s has one label per layer" % p.rect)
		_check(view.call("piece_visible", i), "without a MapReveal every piece is shown")
	var two_by_two: Node3D = null
	for i in view.call("piece_count"):
		if view.call("piece_placement", i).rect.size == Vector2i(2, 2):
			two_by_two = view.call("piece_node", i)
	var one: Node3D = view.call("piece_node", 0)
	_check(two_by_two != null and two_by_two.scale.is_equal_approx(one.scale * Vector3(2.0, 2.0, 1.0)), "a 2x2 piece is twice the size of a 1x1")
	var label: Label3D = view.call("piece_labels", 0)[0]
	_check(label.text.split("\n").size() == def.art_lines.size(), "label text has every art line")
	for body: Node in bodies:
		var shape: BoxShape3D = ((body as Node).get_child(0) as CollisionShape3D).shape as BoxShape3D
		var p: LargeObjectPlacement = map.large_object_at(loader.world_to_cell((body as Node3D).position))
		_check(p != null and shape.size.is_equal_approx(Vector3(p.rect.size.x * cell, def.height, p.rect.size.y * cell)), "collision box covers the footprint")

	# A capsule like the player's walks west into the 3x2 gargoyle (cells 4..6, 3..4) and stops at its edge.
	var player_cfg: PlayerConfig = load(PLAYER_CFG)
	var walker := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = player_cfg.body_radius
	capsule.height = player_cfg.body_height
	shape.shape = capsule
	shape.position.y = player_cfg.body_height * 0.5
	walker.add_child(shape)
	root.add_child(walker)
	walker.global_position = loader.cell_to_world(Vector2i(8, 4))
	for i in 90:
		walker.velocity = Vector3(-3.0, 0.0, 0.0)
		walker.move_and_slide()
		await physics_frame
	var edge: float = 7.0 * cell
	_check(walker.global_position.x >= edge + capsule.radius * 0.9, "the walker stopped at the gargoyle (x %.2f, edge %.2f)" % [walker.global_position.x, edge])
	walker.queue_free()
	view.queue_free()
	loader.queue_free()
	await process_frame


## Statues (task-101): the gargoyle with its baked views. The basin is real geometry inside the footprint; the statue
## is anchored on the footprint centre with a size from the shorter side, small footprints use the coarse bake, and
## turning the camera swaps the shown view (and only the shown view) without moving the piece.
func _check_statues() -> void:
	var legend: MapLegend = _legend()
	var def: LargeObjectDef = legend.large_def(GARGOYLE)
	_check(def.has_views() and def.views.count() >= 8 and def.views_small != null, "the gargoyle has baked views")
	_check(def.views.count() == def.views.arts.size() and def.views.arts.size() == def.views.masks.size(), "every view has a mask")
	var loader: MapLoader = _loader(legend)
	root.add_child(loader)
	var rig := Node3D.new()
	var rig_script := GDScript.new()
	rig_script.source_code = "extends Node3D\nvar yaw: float = 0.0\nfunc current_yaw_degrees() -> float:\n\treturn yaw\n"
	rig_script.reload()
	rig.set_script(rig_script)
	root.add_child(rig)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var view: Node3D = load(VIEW_SCRIPT).new()
	view.set("map_loader", loader)
	view.set("camera_rig", rig)
	root.add_child(view)
	loader.build(loader.parse_text("##########\n#G..GG...#\n#...GG...#\n#.....@..#\n##########"))
	await process_frame
	await process_frame
	var cell: float = loader.world_config.cell_size
	var two: int = -1
	for i in view.call("piece_count"):
		var p: LargeObjectPlacement = view.call("piece_placement", i)
		var short: float = minf(p.rect.size.x, p.rect.size.y)
		_check(view.call("piece_is_statue", i), "piece %s is a statue" % p.rect)
		var node: Node3D = view.call("piece_node", i)
		_check(node.scale.is_equal_approx(Vector3.ONE), "statue root is unscaled")
		var centre: Vector3 = loader.rect_to_world(p.rect)
		_check(is_equal_approx(node.position.x, centre.x) and is_equal_approx(node.position.z, centre.z), "statue %s centred" % p.rect)
		var statue: Node3D = view.call("piece_statue", i)
		_check(is_equal_approx(statue.scale.x, short * cell * def.statue_scale), "statue %s sized by its shorter side" % p.rect)
		var expect: LargeObjectViews = def.views_small if short < def.views_small_below else def.views
		_check(view.call("piece_views", i) == expect, "statue %s uses the %s bake" % [p.rect, "small" if expect == def.views_small else "fine"])
		var labels: Array = view.call("piece_labels", i)
		_check(labels.size() == def.layers().size(), "statue %s has one label per layer" % p.rect)
		_check((labels[0] as Label3D).billboard == BaseMaterial3D.BILLBOARD_ENABLED, "statue labels face the camera")
		var basin: MeshInstance3D = view.call("piece_basin", i)
		_check(basin != null and basin.mesh != null, "statue %s has a basin" % p.rect)
		if basin != null:
			var box: AABB = basin.mesh.get_aabb()
			var inset: float = def.basin_inset * short * cell
			_check(is_equal_approx(box.size.x, p.rect.size.x * cell - 2.0 * inset) and is_equal_approx(box.size.z, p.rect.size.y * cell - 2.0 * inset),
				"basin %s fits the footprint (%s)" % [p.rect, box.size])
			_check(is_equal_approx(box.position.y, 0.0), "basin stands on the floor")
		if p.rect.size == Vector2i(2, 2):
			two = i
	_check(two >= 0, "a 2x2 statue exists")
	if two >= 0:
		var labels: Array = view.call("piece_labels", two)
		var before: int = view.call("piece_view", two)
		var text: String = (labels[0] as Label3D).text
		var position: Vector3 = (view.call("piece_node", two) as Node3D).position
		var views: LargeObjectViews = view.call("piece_views", two)
		rig.set("yaw", 180.0)
		cam.rotation = Vector3(deg_to_rad(-35.264), PI, 0.0)
		await process_frame
		var after: int = view.call("piece_view", two)
		_check(after == views.index_for_yaw(180.0) and after != before, "turning the camera shows another view (%d -> %d)" % [before, after])
		_check((labels[0] as Label3D).text != text, "the view swap changes the label texts")
		_check((view.call("piece_node", two) as Node3D).position.is_equal_approx(position), "the piece stays on its footprint")
		var statue: Node3D = view.call("piece_statue", two)
		_check(statue.position.normalized().is_equal_approx(cam.global_basis.z.normalized()), "the statue is pushed towards the camera")
	view.queue_free()
	cam.queue_free()
	rig.queue_free()
	loader.queue_free()
	await process_frame


func _fast_intro() -> IntroConfig:
	var cfg := IntroConfig.new()
	cfg.black_hold = 0.05
	cfg.wave_fade_in = 0.05
	cfg.wave_hold = 0.05
	cfg.reveal_duration = 0.05
	return cfg


## The arena boots in the main scene: clean parse, spawn, every kind of gargoyle footprint, reveal-aware pieces, and
## every walkable cell reachable from the spawn.
func _check_arena() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var save_path: String = Support.isolate_save(main, SAVE_TAG)
	main.get_node("IntroSequence").set("config", _fast_intro())
	var loader: MapLoader = main.get_node("World/MapLoader")
	loader.map_path = ARENA
	loader.use_cmdline_map = false
	root.add_child(main)
	await _wait(0.8)
	var map: MapData = loader.data
	_check(loader.map_id == &"m2_arena", "arena map id %s" % loader.map_id)
	_check(map.errors.is_empty() and map.warnings.is_empty(), "arena parses cleanly: %s %s" % [map.errors, map.warnings])
	_check(map.has_spawn and map.type_at(map.spawn_cell) == MapLegend.SPAWN, "arena has a spawn")
	_check(map.width >= 40 and map.width <= 50 and map.height >= 30 and map.height <= 34, "arena size %dx%d" % [map.width, map.height])
	var sizes: Dictionary = {}
	# The arena also holds cannons (task-073, drawn by CannonView): only the gargoyles are LargeObjectView pieces.
	var gargoyles: int = 0
	for p in map.large_objects:
		if p.type != GARGOYLE:
			continue
		gargoyles += 1
		sizes[p.rect.size] = true
	for s: Vector2i in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 2)]:
		_check(sizes.has(s), "arena has a %dx%d gargoyle" % [s.x, s.y])
	var counts: Dictionary = {}
	for y in map.height:
		for x in map.width:
			var t: StringName = map.type_at(Vector2i(x, y))
			counts[t] = counts.get(t, 0) + 1
	_check(counts.get(MapLegend.ITEM, 0) >= 2 and counts.get(MapLegend.SPIKES, 0) > 0 and counts.get(MapLegend.CORRUPT, 0) > 0, "arena has items and hazards")
	_check(map.objects.size() >= 2, "arena has pushable objects")
	_check(_reachable_all(map), "every walkable arena cell is reachable from the spawn")
	var runs: Node = main.get_node("RunManager")
	_check(runs.get("phase") == PHASE_PLAYING, "arena run is playing")
	var view: Node3D = main.get_node("LargeObjectView")
	var reveal: Node = main.get_node("MapReveal")
	_check(view.call("piece_count") == gargoyles, "arena: one piece per gargoyle (%d vs %d)" % [view.call("piece_count"), gargoyles])
	# Reveal: pieces far from the spawn are hidden, the ones in sight near it are shown.
	var reach: float = float(reveal.call("effective_reveal_radius")) * loader.world_config.cell_size
	for i in view.call("piece_count"):
		var r: Rect2i = view.call("piece_placement", i).rect
		var far: bool = loader.rect_to_world(r).distance_to(loader.spawn_position) > reach + r.size.length() * loader.world_config.cell_size
		if far:
			_check(not view.call("piece_visible", i), "piece %s far from the spawn is hidden" % r)
	# Walk to the centre fountain (teleport next to it) and it shows.
	var centre_index: int = -1
	for i in view.call("piece_count"):
		if view.call("piece_placement", i).rect.size == Vector2i(3, 2):
			centre_index = i
	_check(centre_index >= 0, "arena has the 3x2 centre fountain")
	if centre_index >= 0:
		var r: Rect2i = view.call("piece_placement", centre_index).rect
		# Task-096: the single form's bigger reveal radius may already reach the fountain from the spawn.
		var fountain_far: bool = loader.rect_to_world(r).distance_to(loader.spawn_position) > reach + r.size.length() * loader.world_config.cell_size
		_check(not fountain_far or not view.call("piece_visible", centre_index), "the centre fountain starts hidden")
		var player: CharacterBody3D = main.get_node("Player")
		player.global_position = loader.cell_to_world(Vector2i(r.position.x + 1, r.end.y + 1))
		await _wait(0.5)
		_check(reveal.call("state_of", Vector2i(r.position.x + 1, r.end.y - 1)) == CELL_SEEN, "the front fountain cells are seen next to it")
		_check(view.call("piece_visible", centre_index), "the centre fountain shows once seen")
		var cell_behind := Vector2i(r.position.x + 1, r.position.y - 2)
		_check(reveal.call("state_of", cell_behind) == CELL_HIDDEN, "the fountain hides the cells behind it")
	main.queue_free()
	await process_frame
	Support.remove_file(save_path)


func _reachable_all(map: MapData) -> bool:
	var steps: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var walk: Array[StringName] = [MapLegend.FLOOR, MapLegend.SPAWN, MapLegend.ITEM]
	var blocked: Dictionary = {}
	for c in map.objects:
		blocked[c] = true
	var seen: Dictionary = {map.spawn_cell: true}
	var queue: Array[Vector2i] = [map.spawn_cell]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for s in steps:
			var n: Vector2i = c + s
			if seen.has(n) or blocked.has(n) or not walk.has(map.type_at(n)):
				continue
			seen[n] = true
			queue.append(n)
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			if walk.has(map.type_at(cell)) and not blocked.has(cell) and not seen.has(cell):
				_failures.append("arena cell %s is unreachable" % cell)
				return false
	return true
