class_name MapLoader
extends Node3D
## Loads a handcrafted ASCII map file and builds its 3D representation: ONE merged glyph-surface
## mesh for everything drawn ("WorldMesh") plus collision bodies and trigger areas under a "Cells"
## container. Never crashes on bad input: problems are logged and recorded in MapData.errors /
## MapData.warnings.

## Emitted after a build, with the data that was built.
signal map_built(data: MapData)

@export var legend: MapLegend
@export var world_config: WorldConfig
## The glyph-surface material of the world mesh (resources/glyphs/glyph_surface_material.tres).
## GlyphWorldView feeds it its uniforms. Null loads the default.
@export var surface_material: Material
## Map text file, e.g. res://data/maps/m1_awakening.txt.
@export_file("*.txt") var map_path: String = ""
## Load and build in _ready.
@export var auto_load: bool = true
## Map chooser (task-060): a `--map=<name or path>` user argument (after `--` on the command line) replaces
## `map_path` in _ready. A bare name is looked up in `maps_dir`.
@export var use_cmdline_map: bool = true
@export_dir var maps_dir: String = "res://data/maps/"

const MAP_ARG_PREFIX := "--map="
const MAP_EXTENSION := "txt"

var data: MapData = MapData.new()
## Identifier of the loaded map (file name without extension); key for per-map persistent data.
var map_id: StringName = &""
## Cells that are drawn (every non-void cell). MapReveal reveals these; what is shown of a cell is
## decided by the reveal mask in the glyph-surface shader.
var drawn_cells: Dictionary[Vector2i, bool] = {}
## The merged world mesh instance (null for an empty map).
var world_mesh: MeshInstance3D
## World position of the spawn cell (centre of the cell, on the floor).
var spawn_position: Vector3 = Vector3.ZERO

const DEFAULT_MATERIAL := "res://resources/glyphs/glyph_surface_material.tres"

var _cells: Node3D
var _bounds: Node3D
## Collision body of every merged prop that blocks movement (task-073: LargeObjects switches it off when destroyed).
var _large_bodies: Dictionary[LargeObjectPlacement, StaticBody3D] = {}


func _ready() -> void:
	if legend == null:
		legend = MapLegend.new()
	if world_config == null:
		world_config = WorldConfig.new()
	set_process(false)
	if use_cmdline_map:
		var chosen: String = map_path_from_args(OS.get_cmdline_user_args(), map_path, maps_dir)
		if chosen != map_path and not FileAccess.file_exists(chosen):
			push_warning("[MapLoader] Map %s from the command line not found; using %s" % [chosen, map_path])
		else:
			map_path = chosen
	map_id = _id_from_path(map_path)
	if auto_load and map_path != "":
		build(load_file(map_path))


## Reads and parses a map file. A missing or unreadable file yields an empty map with an error.
func load_file(path: String) -> MapData:
	map_id = _id_from_path(path)
	if not FileAccess.file_exists(path):
		return _failed("Map file not found: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failed("Cannot open map file %s (error %s)" % [path, error_string(FileAccess.get_open_error())])
	return parse_text(file.get_as_text())


## Parses map text into MapData. Always returns a MapData; check `errors`.
func parse_text(text: String) -> MapData:
	if legend == null:
		legend = MapLegend.new()
	var map := MapData.new()
	var lines: PackedStringArray = text.replace("\r", "").split("\n")
	# Drop trailing blank lines (editors append a final newline).
	while lines.size() > 0 and lines[lines.size() - 1].strip_edges() == "":
		lines.remove_at(lines.size() - 1)
	if lines.is_empty():
		return _failed("Map is empty")

	var max_width: int = 0
	for line in lines:
		max_width = maxi(max_width, line.length())
	map.width = max_width
	map.height = lines.size()
	map.types.resize(max_width * lines.size())
	map.types.fill(MapLegend.VOID)

	# Teleports (task-068) first: their cells (ring, channel centre, broken T groups) are floor whatever their character.
	var teleport_cells: Dictionary[Vector2i, bool] = TeleportPad.parse(lines, legend.teleport_char, legend.teleport_channels,
			map.teleports, map.broken_teleports)
	var unknown_seen: Dictionary = {}
	var ragged: bool = false
	var first_floor: Vector2i = Vector2i(-1, -1)
	for y in lines.size():
		var line: String = lines[y]
		if line.length() != max_width:
			ragged = true
		for x in line.length():
			var ch: String = line[x]
			if teleport_cells.has(Vector2i(x, y)):
				if first_floor.x < 0:
					first_floor = Vector2i(x, y)
				map.set_type(Vector2i(x, y), MapLegend.FLOOR)
				continue
			# Enemies (task-075) and black holes (task-076) stand on floor.
			if legend.enemy_spawns.has(ch) or ch == legend.black_hole_char:
				if legend.enemy_spawns.has(ch):
					map.enemies.append(Vector2i(x, y))
					map.enemy_types.append(legend.enemy_spawns[ch])
				else:
					map.black_holes.append(Vector2i(x, y))
				if first_floor.x < 0:
					first_floor = Vector2i(x, y)
				map.set_type(Vector2i(x, y), MapLegend.FLOOR)
				continue
			var type: StringName = legend.type_for(ch)
			if type == &"":
				if not unknown_seen.has(ch):
					unknown_seen[ch] = Vector2i(x, y)
				type = legend.unknown_type
			var cell := Vector2i(x, y)
			if type == MapLegend.SPAWN:
				if map.has_spawn:
					map.warnings.append("Extra spawn '@' at %s ignored (using %s)" % [cell, map.spawn_cell])
					type = MapLegend.FLOOR
				else:
					map.has_spawn = true
					map.spawn_cell = cell
			if type == MapLegend.OBJECT:
				map.objects.append(cell)
				type = MapLegend.FLOOR
			if first_floor.x < 0 and (type == MapLegend.FLOOR or type == MapLegend.SPAWN):
				first_floor = cell
			map.set_type(cell, type)

	# Multi-cell props (task-058): adjacent cells of one large type merge into rectangles; their cells keep the type.
	map.large_objects = LargeObjectMerger.merge(map, legend.large_objects)
	# Dirt (task-070) blocks light like a wall until DirtWalls destroys it (its cell turns into floor).
	map.light_blocking_types[MapLegend.DIRT] = true
	for type: StringName in legend.large_objects:
		var def: LargeObjectDef = legend.large_objects[type]
		if def != null and def.blocks_light:
			map.light_blocking_types[type] = true

	if ragged:
		map.warnings.append("Ragged rows: padded shorter rows to width %d with void" % max_width)
	for ch: String in unknown_seen:
		map.warnings.append("Unknown character '%s' first at %s treated as %s" % [ch, unknown_seen[ch], legend.unknown_type])
	if not map.has_spawn:
		if first_floor.x >= 0:
			map.spawn_cell = first_floor
			map.has_spawn = true
			map.errors.append("Map has no spawn '@'; using first floor cell %s" % first_floor)
		else:
			map.errors.append("Map has no spawn '@' and no floor cell; spawning at origin")
	for w in map.warnings:
		push_warning("[MapLoader] " + w)
	for e in map.errors:
		push_error("[MapLoader] " + e)
	return map


## Replaces the current 3D map with the one described by `map`. An empty map builds nothing.
func build(map: MapData) -> void:
	if legend == null:
		legend = MapLegend.new()
	if world_config == null:
		world_config = WorldConfig.new()
	if surface_material == null:
		surface_material = load(DEFAULT_MATERIAL) as Material
	data = map
	_clear()
	spawn_position = cell_to_world(map.spawn_cell)
	if not map.is_empty():
		_build_geometry(map)
		_build_bounds(map)
	map_built.emit(map)


## World position of the centre of a cell, on the floor plane (y = 0).
func cell_to_world(cell: Vector2i) -> Vector3:
	var size: float = world_config.cell_size
	return Vector3((cell.x + 0.5) * size, 0.0, (cell.y + 0.5) * size)


## True when the cell is drawn (not void, inside the map).
func is_drawn(cell: Vector2i) -> bool:
	return drawn_cells.has(cell)


## Cell containing a world position.
func world_to_cell(pos: Vector3) -> Vector2i:
	var size: float = world_config.cell_size
	return Vector2i(floori(pos.x / size), floori(pos.z / size))


## Map path chosen by the user arguments: the last `--map=<value>` wins. A value with a directory (`res://...`,
## `data/maps/x.txt`) is used as a path (`res://` added when missing); a bare name (`m2_arena` or `m2_arena.txt`) is
## looked up in `dir`. Without a usable argument `fallback` is returned.
static func map_path_from_args(args: PackedStringArray, fallback: String, dir: String) -> String:
	var value: String = ""
	for arg in args:
		if arg.begins_with(MAP_ARG_PREFIX):
			value = arg.substr(MAP_ARG_PREFIX.length()).strip_edges().replace("\\", "/")
	if value == "":
		return fallback
	if value.get_extension() == "":
		value += "." + MAP_EXTENSION
	if value.contains("://"):
		return value
	if value.contains("/"):
		return "res://" + value.trim_prefix("/")
	return dir.path_join(value)


func _id_from_path(path: String) -> StringName:
	return StringName(path.get_file().get_basename())


func _failed(message: String) -> MapData:
	push_error("[MapLoader] " + message)
	var map := MapData.new()
	map.errors.append(message)
	return map


func _clear() -> void:
	drawn_cells.clear()
	_large_bodies.clear()
	if world_mesh != null:
		world_mesh.free()
		world_mesh = null
	if _cells != null:
		_cells.free()
	if _bounds != null:
		_bounds.free()
	_cells = Node3D.new()
	_cells.name = "Cells"
	add_child(_cells)
	_bounds = Node3D.new()
	_bounds.name = "Bounds"
	add_child(_bounds)


func _build_geometry(map: MapData) -> void:
	var builder := WorldMeshBuilder.new()
	var mesh: ArrayMesh = builder.build(map, world_config)
	if mesh != null:
		world_mesh = MeshInstance3D.new()
		world_mesh.name = "WorldMesh"
		world_mesh.mesh = mesh
		world_mesh.material_override = surface_material
		world_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(world_mesh)
	for y in map.height:
		var x: int = 0
		while x < map.width:
			var type: StringName = map.type_at(Vector2i(x, y))
			if type == MapLegend.VOID:
				x += 1
				continue
			# Walls: merge horizontal runs into one collision body each.
			if type == MapLegend.WALL:
				var run: int = _run_length(map, x, y, MapLegend.WALL)
				for i in run:
					drawn_cells[Vector2i(x + i, y)] = true
				_cells.add_child(_make_wall(x, y, run))
				x += run
				continue
			var cell := Vector2i(x, y)
			drawn_cells[cell] = true
			if type == MapLegend.ITEM:
				_cells.add_child(_make_item(cell))
			elif type == MapLegend.SPIKES:
				_cells.add_child(_make_spikes(cell))
			elif type == MapLegend.CORRUPT:
				_cells.add_child(_make_corrupt(cell))
			x += 1
	for placement in map.large_objects:
		var def: LargeObjectDef = legend.large_def(placement.type)
		if def != null and def.blocks_movement:
			var body: StaticBody3D = _make_large(placement, def)
			_large_bodies[placement] = body
			_cells.add_child(body)


func _run_length(map: MapData, x: int, y: int, type: StringName) -> int:
	var n: int = 0
	while x + n < map.width and map.type_at(Vector2i(x + n, y)) == type:
		n += 1
	return n


func _collision_box(box_size: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box_size
	shape.shape = bs
	return shape


func _make_wall(x: int, y: int, run: int) -> StaticBody3D:
	var s: float = world_config.cell_size
	var box_size := Vector3(run * s, world_config.wall_height, s)
	var body := StaticBody3D.new()
	body.name = "Wall_%d_%d" % [x, y]
	body.position = Vector3((x + run * 0.5) * s, world_config.wall_height * 0.5, (y + 0.5) * s)
	body.set_meta(&"cell_type", MapLegend.WALL)
	body.add_child(_collision_box(box_size))
	return body


## One collision box over the whole footprint of a merged multi-cell prop (task-058).
func _make_large(placement: LargeObjectPlacement, def: LargeObjectDef) -> StaticBody3D:
	var s: float = world_config.cell_size
	var r: Rect2i = placement.rect
	var body := StaticBody3D.new()
	body.name = "Large_%s_%d_%d" % [String(placement.type), r.position.x, r.position.y]
	body.position = Vector3((r.position.x + r.size.x * 0.5) * s, def.height * 0.5, (r.position.y + r.size.y * 0.5) * s)
	body.set_meta(&"cell_type", placement.type)
	body.add_to_group(&"map_large_objects")
	body.add_child(_collision_box(Vector3(r.size.x * s, def.height, r.size.y * s)))
	return body


## The collision body of a merged prop (null when it has none).
func large_body(placement: LargeObjectPlacement) -> StaticBody3D:
	return _large_bodies.get(placement, null)


## World position of the centre of a cell rectangle, on the floor plane.
func rect_to_world(rect: Rect2i) -> Vector3:
	var size: float = world_config.cell_size
	return Vector3((rect.position.x + rect.size.x * 0.5) * size, 0.0, (rect.position.y + rect.size.y * 0.5) * size)


func _make_cell_area(cell: Vector2i, type: StringName, group: StringName, height: float) -> MapCell:
	var area := MapCell.new()
	area.name = "%s_%d_%d" % [String(type).capitalize(), cell.x, cell.y]
	area.cell_type = type
	area.cell = cell
	area.position = cell_to_world(cell)
	area.add_to_group(group)
	var s: float = world_config.cell_size
	var shape := _collision_box(Vector3(s, height, s))
	shape.position.y = height * 0.5
	area.add_child(shape)
	return area


func _make_item(cell: Vector2i) -> MapCell:
	return _make_cell_area(cell, MapLegend.ITEM, &"map_items", world_config.item_height)


func _make_spikes(cell: Vector2i) -> MapCell:
	var area := _make_cell_area(cell, MapLegend.SPIKES, &"map_hazards", world_config.spike_height)
	area.add_to_group(&"map_spikes")
	return area


func _make_corrupt(cell: Vector2i) -> MapCell:
	var area := _make_cell_area(cell, MapLegend.CORRUPT, &"map_hazards", world_config.corrupt_height)
	area.add_to_group(&"map_corrupt")
	return area


## Invisible collision that keeps bodies inside the map: boxes on void cells that touch playable
## cells (merged into horizontal runs) plus four slabs just outside the map rectangle.
func _build_bounds(map: MapData) -> void:
	var size: float = world_config.cell_size
	var h: float = world_config.wall_height
	for y in map.height:
		var x: int = 0
		while x < map.width:
			if not _is_void_edge(map, Vector2i(x, y)):
				x += 1
				continue
			var run: int = 0
			while x + run < map.width and _is_void_edge(map, Vector2i(x + run, y)):
				run += 1
			_add_bound("Void_%d_%d" % [x, y], Vector3((x + run * 0.5) * size, h * 0.5, (y + 0.5) * size), Vector3(run * size, h, size))
			x += run
	var w: float = map.width * size
	var d: float = map.height * size
	var t: float = size
	_add_bound("Edge_N", Vector3(w * 0.5, h * 0.5, -t * 0.5), Vector3(w + 2.0 * t, h, t))
	_add_bound("Edge_S", Vector3(w * 0.5, h * 0.5, d + t * 0.5), Vector3(w + 2.0 * t, h, t))
	_add_bound("Edge_W", Vector3(-t * 0.5, h * 0.5, d * 0.5), Vector3(t, h, d + 2.0 * t))
	_add_bound("Edge_E", Vector3(w + t * 0.5, h * 0.5, d * 0.5), Vector3(t, h, d + 2.0 * t))


## A void cell with at least one non-void cell among its eight neighbours.
func _is_void_edge(map: MapData, cell: Vector2i) -> bool:
	if map.type_at(cell) != MapLegend.VOID:
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := cell + Vector2i(dx, dy)
			if map.in_bounds(n) and map.type_at(n) != MapLegend.VOID:
				return true
	return false


func _add_bound(bound_name: String, pos: Vector3, box_size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = bound_name
	body.position = pos
	body.set_meta(&"cell_type", MapLegend.VOID)
	body.add_child(_collision_box(box_size))
	_bounds.add_child(body)
