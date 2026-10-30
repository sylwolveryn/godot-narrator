class_name MapLoader
extends Node3D
## Loads a handcrafted ASCII map file and builds its 3D representation as children
## of a "Cells" container. Never crashes on bad input: problems are logged and
## recorded in MapData.errors / MapData.warnings.

## Emitted after a build, with the data that was built.
signal map_built(data: MapData)

@export var legend: MapLegend
@export var world_config: WorldConfig
## Spike pulse and corruption breathing values baked into the world materials.
@export var hazard_fx: HazardFxConfig
## Map text file, e.g. res://data/maps/m1_awakening.txt.
@export_file("*.txt") var map_path: String = ""
## Load and build in _ready.
@export var auto_load: bool = true

var data: MapData = MapData.new()
## Identifier of the loaded map (file name without extension); key for per-map persistent data.
var map_id: StringName = &""
## Cell -> Array of the MeshInstance3D nodes that draw it. Each mesh carries a `kind` meta
## (a MapLegend cell type). Used by MapReveal to hide, show and restyle cells.
var visuals: Dictionary[Vector2i, Array] = {}
## World position of the spawn cell (centre of the cell, on the floor).
var spawn_position: Vector3 = Vector3.ZERO

const WORLD_SHADER := "res://shaders/world_encode.gdshader"

var _cells: Node3D
var _bounds: Node3D


func _ready() -> void:
	if legend == null:
		legend = MapLegend.new()
	if world_config == null:
		world_config = WorldConfig.new()
	if hazard_fx == null:
		hazard_fx = HazardFxConfig.new()
	set_process(false)
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
	if hazard_fx == null:
		hazard_fx = HazardFxConfig.new()
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


## Meshes that draw a cell (empty array for none).
func visuals_at(cell: Vector2i) -> Array:
	return visuals.get(cell, [])


## Cell containing a world position.
func world_to_cell(pos: Vector3) -> Vector2i:
	var size: float = world_config.cell_size
	return Vector2i(floori(pos.x / size), floori(pos.z / size))


func _id_from_path(path: String) -> StringName:
	return StringName(path.get_file().get_basename())


func _register(cell: Vector2i, mesh: MeshInstance3D, kind: StringName) -> void:
	mesh.set_meta(&"kind", kind)
	if not visuals.has(cell):
		visuals[cell] = []
	visuals[cell].append(mesh)


func _failed(message: String) -> MapData:
	push_error("[MapLoader] " + message)
	var map := MapData.new()
	map.errors.append(message)
	return map


func _clear() -> void:
	visuals.clear()
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
	var wall_mat: ShaderMaterial = _world_material(MaterialIds.WALL, world_config.wall_luminance)
	_apply_structure_look(wall_mat)
	var floor_mat: ShaderMaterial = _world_material(MaterialIds.FLOOR, world_config.floor_luminance)
	var item_mat: ShaderMaterial = _world_material(MaterialIds.ITEM, -1.0, world_config.item_luminance)
	var spike_mat: ShaderMaterial = _world_material(MaterialIds.SPIKES, -1.0, hazard_fx.spike_base_l,
			hazard_fx.spike_pulse_amp, hazard_fx.spike_pulse_hz)
	var corrupt_mat: ShaderMaterial = _world_material(MaterialIds.CORRUPT, -1.0, hazard_fx.corrupt_base_l,
			hazard_fx.corrupt_l_amp, hazard_fx.corrupt_l_hz)

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
			for i in floor_run:
				var cell := Vector2i(x + i, y)
				_cells.add_child(_make_floor(cell, floor_mat))
				var t: StringName = map.type_at(cell)
				if t == MapLegend.ITEM:
					_cells.add_child(_make_item(cell, item_mat))
				elif t == MapLegend.SPIKES:
					_cells.add_child(_make_spikes(cell, spike_mat))
				elif t == MapLegend.CORRUPT:
					_cells.add_child(_make_corrupt(cell, corrupt_mat))
			x += floor_run


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


## A world material: it writes data for the ASCII post-process instead of a colour (see
## shaders/world_encode.gdshader). `emissive_l` of 0 or more makes it emissive and pulsing.
func _world_material(id: int, lit_l: float, emissive_l: float = -1.0, pulse_amp: float = 0.0, pulse_hz: float = 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(WORLD_SHADER) as Shader
	mat.set_shader_parameter("material_id", id)
	mat.set_shader_parameter("lit_l", lit_l)
	mat.set_shader_parameter("emissive_l", emissive_l)
	mat.set_shader_parameter("pulse_amp", pulse_amp)
	mat.set_shader_parameter("pulse_hz", pulse_hz)
	mat.set_shader_parameter("height_ref", world_config.wall_height)
	return mat


## Face shading, edges and detail noise for lit boxes (WorldConfig "Structure look").
func _apply_structure_look(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("shade_faces", true)
	mat.set_shader_parameter("face_top", world_config.face_top)
	mat.set_shader_parameter("face_side_lit", world_config.face_side_lit)
	mat.set_shader_parameter("face_side_dark", world_config.face_side_dark)
	mat.set_shader_parameter("foot_shade", world_config.foot_shade)
	mat.set_shader_parameter("edge_width", world_config.edge_width)
	mat.set_shader_parameter("edge_boost", world_config.edge_boost)
	mat.set_shader_parameter("detail_scale", world_config.detail_scale)
	mat.set_shader_parameter("detail_amp", world_config.detail_amp)


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
	body.add_child(_collision_box(box_size))
	# One visual box per cell so single cells can be revealed; the collision stays merged.
	for i in run:
		var mesh := _box_mesh(Vector3(s, world_config.wall_height, s), mat)
		mesh.name = "Visual_%d" % i
		mesh.position.x = (i + 0.5 - run * 0.5) * s
		_register(Vector2i(x + i, y), mesh, MapLegend.WALL)
		body.add_child(mesh)
	return body


func _make_floor(cell: Vector2i, mat: Material) -> MeshInstance3D:
	var s: float = world_config.cell_size
	var t: float = world_config.floor_thickness
	var mesh := _box_mesh(Vector3(s, t, s), mat)
	mesh.name = "Floor_%d_%d" % [cell.x, cell.y]
	mesh.position = Vector3((cell.x + 0.5) * s, -t * 0.5, (cell.y + 0.5) * s)
	_register(cell, mesh, MapLegend.FLOOR)
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
	_register(cell, mesh, MapLegend.ITEM)
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
			_register(cell, cone, MapLegend.SPIKES)
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
	_register(cell, quad, MapLegend.CORRUPT)
	area.add_child(quad)
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
