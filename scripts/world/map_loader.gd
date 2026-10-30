class_name MapLoader
extends Node3D
## Loads a handcrafted ASCII map file and builds its 3D representation as children
## of a "Cells" container. Never crashes on bad input: problems are logged and
## recorded in MapData.errors / MapData.warnings.

## Emitted after a build, with the data that was built.
signal map_built(data: MapData)

@export var legend: MapLegend
@export var world_config: WorldConfig
## Map text file, e.g. res://data/maps/m1_awakening.txt.
@export_file("*.txt") var map_path: String = ""
## Load and build in _ready.
@export var auto_load: bool = true

var data: MapData = MapData.new()
## World position of the spawn cell (centre of the cell, on the floor).
var spawn_position: Vector3 = Vector3.ZERO

var _cells: Node3D
var _corrupt_material: StandardMaterial3D
var _time: float = 0.0


func _ready() -> void:
	if legend == null:
		legend = MapLegend.new()
	if world_config == null:
		world_config = WorldConfig.new()
	set_process(false)
	if auto_load and map_path != "":
		build(load_file(map_path))


func _process(delta: float) -> void:
	# Corrupting patches pulse so they read as unstable in the ASCII output.
	_time += delta
	var wave: float = 0.5 + 0.5 * sin(_time * world_config.corrupt_pulse_speed)
	var k: float = 1.0 - world_config.corrupt_pulse_depth * wave
	_corrupt_material.albedo_color = world_config.corrupt_color * k


## Reads and parses a map file. A missing or unreadable file yields an empty map with an error.
func load_file(path: String) -> MapData:
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

	var unknown_seen: Dictionary = {}
	var ragged: bool = false
	var first_floor: Vector2i = Vector2i(-1, -1)
	for y in lines.size():
		var line: String = lines[y]
		if line.length() != max_width:
			ragged = true
		for x in line.length():
			var ch: String = line[x]
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
			if first_floor.x < 0 and (type == MapLegend.FLOOR or type == MapLegend.SPAWN):
				first_floor = cell
			map.set_type(cell, type)

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
	data = map
	_clear()
	spawn_position = cell_to_world(map.spawn_cell)
	if not map.is_empty():
		_build_geometry(map)
	map_built.emit(map)


## World position of the centre of a cell, on the floor plane (y = 0).
func cell_to_world(cell: Vector2i) -> Vector3:
	var size: float = world_config.cell_size
	return Vector3((cell.x + 0.5) * size, 0.0, (cell.y + 0.5) * size)


func _failed(message: String) -> MapData:
	push_error("[MapLoader] " + message)
	var map := MapData.new()
	map.errors.append(message)
	return map


func _clear() -> void:
	set_process(false)
	if _cells != null:
		_cells.free()
	_cells = Node3D.new()
	_cells.name = "Cells"
	add_child(_cells)


func _build_geometry(map: MapData) -> void:
	var wall_mat: StandardMaterial3D = _unshaded(world_config.wall_color)
	var floor_mat: StandardMaterial3D = _unshaded(world_config.floor_color)
	var item_mat: StandardMaterial3D = _unshaded(world_config.item_color)
	var spike_mat: StandardMaterial3D = _unshaded(world_config.spike_color)
	_corrupt_material = _unshaded(world_config.corrupt_color)

	for y in map.height:
		var x: int = 0
		while x < map.width:
			var type: StringName = map.type_at(Vector2i(x, y))
			if type == MapLegend.VOID:
				x += 1
				continue
			# Walls: merge horizontal runs into one body each.
			if type == MapLegend.WALL:
				var run: int = _run_length(map, x, y, MapLegend.WALL)
				_cells.add_child(_make_wall(x, y, run, wall_mat))
				x += run
				continue
			# Every non-wall, non-void cell has floor under it.
			var floor_run: int = _run_floor(map, x, y)
			_cells.add_child(_make_floor(x, y, floor_run, floor_mat))
			for i in floor_run:
				var cell := Vector2i(x + i, y)
				var t: StringName = map.type_at(cell)
				if t == MapLegend.ITEM:
					_cells.add_child(_make_item(cell, item_mat))
				elif t == MapLegend.SPIKES:
					_cells.add_child(_make_spikes(cell, spike_mat))
				elif t == MapLegend.CORRUPT:
					_cells.add_child(_make_corrupt(cell, _corrupt_material))
			x += floor_run
	set_process(world_config.corrupt_pulse_depth > 0.0)


func _run_length(map: MapData, x: int, y: int, type: StringName) -> int:
	var n: int = 0
	while x + n < map.width and map.type_at(Vector2i(x + n, y)) == type:
		n += 1
	return n


func _run_floor(map: MapData, x: int, y: int) -> int:
	var n: int = 0
	while x + n < map.width:
		var t: StringName = map.type_at(Vector2i(x + n, y))
		if t == MapLegend.VOID or t == MapLegend.WALL:
			break
		n += 1
	return n


func _unshaded(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat


func _box_mesh(box_size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	box.material = mat
	mesh.mesh = box
	return mesh


func _collision_box(box_size: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box_size
	shape.shape = bs
	return shape


func _make_wall(x: int, y: int, run: int, mat: Material) -> StaticBody3D:
	var s: float = world_config.cell_size
	var box_size := Vector3(run * s, world_config.wall_height, s)
	var body := StaticBody3D.new()
	body.name = "Wall_%d_%d" % [x, y]
	body.position = Vector3((x + run * 0.5) * s, world_config.wall_height * 0.5, (y + 0.5) * s)
	body.set_meta(&"cell_type", MapLegend.WALL)
	body.add_child(_box_mesh(box_size, mat))
	body.add_child(_collision_box(box_size))
	return body


func _make_floor(x: int, y: int, run: int, mat: Material) -> MeshInstance3D:
	var s: float = world_config.cell_size
	var t: float = world_config.floor_thickness
	var mesh := _box_mesh(Vector3(run * s, t, s), mat)
	mesh.name = "Floor_%d_%d" % [x, y]
	mesh.position = Vector3((x + run * 0.5) * s, -t * 0.5, (y + 0.5) * s)
	return mesh


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


func _make_item(cell: Vector2i, mat: Material) -> MapCell:
	var area := _make_cell_area(cell, MapLegend.ITEM, &"map_items", world_config.item_height)
	var edge: float = world_config.cell_size * world_config.item_size_ratio
	var mesh := _box_mesh(Vector3(edge, edge, edge), mat)
	mesh.position.y = world_config.item_height
	mesh.rotation.y = PI * 0.25
	area.add_child(mesh)
	return area


func _make_spikes(cell: Vector2i, mat: Material) -> MapCell:
	var area := _make_cell_area(cell, MapLegend.SPIKES, &"map_hazards", world_config.spike_height)
	area.add_to_group(&"map_spikes")
	var n: int = world_config.spike_grid
	var sub: float = world_config.cell_size / float(n)
	for ix in n:
		for iz in n:
			var cone := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.0
			cyl.bottom_radius = sub * world_config.spike_radius_ratio
			cyl.height = world_config.spike_height
			cyl.radial_segments = 8
			cyl.rings = 1
			cyl.material = mat
			cone.mesh = cyl
			cone.position = Vector3((ix + 0.5) * sub - world_config.cell_size * 0.5,
					world_config.spike_height * 0.5, (iz + 0.5) * sub - world_config.cell_size * 0.5)
			area.add_child(cone)
	return area


func _make_corrupt(cell: Vector2i, mat: Material) -> MapCell:
	var area := _make_cell_area(cell, MapLegend.CORRUPT, &"map_hazards", world_config.corrupt_height)
	area.add_to_group(&"map_corrupt")
	var quad := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(world_config.cell_size, world_config.cell_size)
	plane.material = mat
	quad.mesh = plane
	quad.position.y = world_config.corrupt_height
	area.add_child(quad)
	return area
