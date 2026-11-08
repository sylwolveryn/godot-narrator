class_name WorldMeshBuilder
extends RefCounted
## Builds the whole map as ONE ArrayMesh for the glyph-surface material (one surface, one draw call).
## Per vertex: COLOR.r = GlyphSurfaceType id / TYPE_DIV, UV = the map cell the vertex belongs to (the
## shader reads the reveal mask with it), NORMAL = the flat face normal.
## Every non-void cell has a floor quad (under walls it shows where the cut-away opens a wall).
## Tops and all four side faces are emitted (the player can orbit the camera, task-051); faces between two wall cells
## are skipped, and the material back-face culls the sides turned away from the camera.
## Per vertex (carved-stone look, task-036): COLOR.g = edge bits / EDGE_DIV for wall faces (top face: bit0 -x,
## bit1 +x, bit2 -z, bit3 +z side has no wall neighbour; side face: bit0 / bit1 = low / high end of the face is a
## free corner), COLOR.b = 1 on the floor quad under a wall (the shader samples wall-region light data there).

## Triangle vertex order of a quad (a, b, c, d).
const QUAD_ORDER: Array[int] = [0, 1, 2, 0, 2, 3]
## Neighbour cell for each bit of a top face's edge bits: -x, +x, -z, +z.
const SIDE_STEPS: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
## Edge bit divisor (the shader multiplies COLOR.g by the same value).
const EDGE_DIV: float = 16.0
## COLOR.b of the vertices of a small object (a wall cell's floor quad uses 1.0, everything else 0.0).
const FREE_STANDING: float = 0.5
const CORRUPT_SEED_A: float = 12.9898
const CORRUPT_SEED_B: float = 78.233
const CORRUPT_SEED_SALT: float = 37.719
const CORRUPT_HASH_MUL: float = 43758.5453

var _config: WorldConfig
var _positions: PackedVector3Array = PackedVector3Array()
var _normals: PackedVector3Array = PackedVector3Array()
var _colors: PackedColorArray = PackedColorArray()
var _uvs: PackedVector2Array = PackedVector2Array()
var _cell: Vector2i = Vector2i.ZERO
var _edge_bits: int = 0
var _under_wall: bool = false
## Vertex marker COLOR.b = FREE_STANDING for a small object (wall-type surface that is not part of a wall cell).
var _free_standing: bool = false


## Mesh of the whole map; null for an empty map.
func build(map: MapData, config: WorldConfig) -> ArrayMesh:
	_config = config
	_positions.clear()
	_normals.clear()
	_colors.clear()
	_uvs.clear()
	if map.is_empty():
		return null
	for y in map.height:
		for x in map.width:
			_cell = Vector2i(x, y)
			var type: StringName = map.type_at(_cell)
			if type == MapLegend.VOID:
				continue
			_under_wall = type == MapLegend.WALL
			_edge_bits = 0
			_floor()
			_under_wall = false
			if type == MapLegend.WALL:
				_wall(map)
				continue
			match type:
				MapLegend.ITEM:
					_item()
				MapLegend.SPIKES:
					_spikes()
				MapLegend.CORRUPT:
					_corruption()
	if _positions.is_empty():
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _positions
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Mesh of ONE small pushable object (task-019), centred on the origin of its cell, standing on y = 0: a stone block
## with a top and its four side faces. Wall-type surface; COLOR.b = FREE_STANDING tells the shader it is not a wall cell
## (UV is zero: the shader takes the cell from the instance origin).
func build_object(config: WorldConfig) -> ArrayMesh:
	_config = config
	_positions.clear()
	_normals.clear()
	_colors.clear()
	_uvs.clear()
	_cell = Vector2i.ZERO
	_edge_bits = 0
	_under_wall = false
	_free_standing = true
	var half: float = config.object_size_ratio * config.cell_size * 0.5
	_box(0.0, 0.0, 0.0, config.object_height, half, half, GlyphSurfaceType.WALL, true, true)
	_free_standing = false
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _positions
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Number of triangles of the last build.
func triangle_count() -> int:
	return _positions.size() / 3


func _origin() -> Vector3:
	return Vector3(_cell.x, 0.0, _cell.y) * _config.cell_size


func _floor() -> void:
	var o: Vector3 = _origin()
	var s: float = _config.cell_size
	_quad(o, o + Vector3(s, 0, 0), o + Vector3(s, 0, s), o + Vector3(0, 0, s), Vector3.UP, GlyphSurfaceType.FLOOR)


func _wall(map: MapData) -> void:
	var s: float = _config.cell_size
	var o: Vector3 = _origin() + Vector3(s, 0, s) * 0.5
	var face_x: bool = not _is_wall(map, _cell + Vector2i(1, 0))
	var face_z: bool = not _is_wall(map, _cell + Vector2i(0, 1))
	var face_nx: bool = not _is_wall(map, _cell + Vector2i(-1, 0))
	var face_nz: bool = not _is_wall(map, _cell + Vector2i(0, -1))
	var top_bits: int = 0
	for i in SIDE_STEPS.size():
		if not _is_wall(map, _cell + SIDE_STEPS[i]):
			top_bits |= 1 << i
	_edge_bits = top_bits
	_quad_top(o, s)
	if face_x:
		_edge_bits = _end_bits(map, Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0))
		_box_side_x(o, s)
	if face_z:
		_edge_bits = _end_bits(map, Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1))
		_box_side_z(o, s)
	if face_nx:
		_edge_bits = _end_bits(map, Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0))
		_box_side_nx(o, s)
	if face_nz:
		_edge_bits = _end_bits(map, Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1))
		_box_side_nz(o, s)
	_edge_bits = 0


## A face of a wall continues past its end when the neighbour there is a wall that shows the same face.
func _end_bits(map: MapData, low: Vector2i, high: Vector2i, out: Vector2i) -> int:
	var bits: int = 0
	if not (_is_wall(map, _cell + low) and not _is_wall(map, _cell + low + out)):
		bits |= 1
	if not (_is_wall(map, _cell + high) and not _is_wall(map, _cell + high + out)):
		bits |= 2
	return bits


func _is_wall(map: MapData, cell: Vector2i) -> bool:
	return map.type_at(cell) == MapLegend.WALL


func _quad_top(o: Vector3, s: float) -> void:
	var h: float = s * 0.5
	var y: float = _config.wall_height
	_quad(Vector3(o.x - h, y, o.z - h), Vector3(o.x + h, y, o.z - h), Vector3(o.x + h, y, o.z + h), Vector3(o.x - h, y, o.z + h), Vector3.UP, GlyphSurfaceType.WALL)


func _box_side_x(o: Vector3, s: float) -> void:
	var h: float = s * 0.5
	var y1: float = _config.wall_height
	_quad(Vector3(o.x + h, 0.0, o.z - h), Vector3(o.x + h, 0.0, o.z + h), Vector3(o.x + h, y1, o.z + h), Vector3(o.x + h, y1, o.z - h), Vector3.RIGHT, GlyphSurfaceType.WALL)


func _box_side_z(o: Vector3, s: float) -> void:
	var h: float = s * 0.5
	var y1: float = _config.wall_height
	_quad(Vector3(o.x - h, 0.0, o.z + h), Vector3(o.x + h, 0.0, o.z + h), Vector3(o.x + h, y1, o.z + h), Vector3(o.x - h, y1, o.z + h), Vector3.BACK, GlyphSurfaceType.WALL)


func _box_side_nx(o: Vector3, s: float) -> void:
	var h: float = s * 0.5
	var y1: float = _config.wall_height
	_quad(Vector3(o.x - h, 0.0, o.z - h), Vector3(o.x - h, 0.0, o.z + h), Vector3(o.x - h, y1, o.z + h), Vector3(o.x - h, y1, o.z - h), Vector3.LEFT, GlyphSurfaceType.WALL)


func _box_side_nz(o: Vector3, s: float) -> void:
	var h: float = s * 0.5
	var y1: float = _config.wall_height
	_quad(Vector3(o.x - h, 0.0, o.z - h), Vector3(o.x + h, 0.0, o.z - h), Vector3(o.x + h, y1, o.z - h), Vector3(o.x - h, y1, o.z - h), Vector3.FORWARD, GlyphSurfaceType.WALL)


func _item() -> void:
	var s: float = _config.cell_size
	var c: Vector3 = _origin() + Vector3(s, 0, s) * 0.5
	var half: float = _config.item_pillar_half * s
	_box(c.x, c.z, 0.0, _config.item_pillar_height, half, half, GlyphSurfaceType.ITEM, true, true)


func _spikes() -> void:
	var n: int = _config.spike_pyramid_grid
	var s: float = _config.cell_size
	var o: Vector3 = _origin()
	var half: float = _config.spike_pyramid_half * s
	for ix in n:
		for iz in n:
			var base := Vector3(o.x + (ix + 0.5) * s / n, 0.0, o.z + (iz + 0.5) * s / n)
			var apex: Vector3 = base + Vector3(0, _config.spike_pyramid_height, 0)
			var corners: Array[Vector3] = [
				base + Vector3(-half, 0, -half), base + Vector3(half, 0, -half),
				base + Vector3(half, 0, half), base + Vector3(-half, 0, half)]
			for i in 4:
				_tri(corners[i], corners[(i + 1) % 4], apex, base, GlyphSurfaceType.SPIKES)


func _corruption() -> void:
	var n: int = _config.corrupt_grid
	var s: float = _config.cell_size
	var o: Vector3 = _origin()
	var half: float = _config.corrupt_column_half * s
	for sx in n:
		for sz in n:
			var sub := Vector2i(_cell.x * n + sx, _cell.y * n + sz)
			if _hash(sub, 0.0) < _config.corrupt_gap_chance:
				continue
			var height: float = _config.corrupt_column_min + _config.corrupt_column_span * _hash(sub, 1.0) * _hash(sub, 2.0)
			_box(o.x + (sx + 0.5) * s / n, o.z + (sz + 0.5) * s / n, 0.0, height, half, half, GlyphSurfaceType.CORRUPT, true, true)


## Deterministic hash in 0..1 of a sub-cell (stable across builds and runs).
func _hash(c: Vector2i, salt: float) -> float:
	return fposmod(sin(float(c.x) * CORRUPT_SEED_A + float(c.y) * CORRUPT_SEED_B + salt * CORRUPT_SEED_SALT) * CORRUPT_HASH_MUL, 1.0)


## Box with a top and optionally the x / z side faces (both signs each: the camera can orbit, task-051).
func _box(cx: float, cz: float, y0: float, y1: float, hx: float, hz: float, type: int, face_x: bool, face_z: bool) -> void:
	_quad(Vector3(cx - hx, y1, cz - hz), Vector3(cx + hx, y1, cz - hz), Vector3(cx + hx, y1, cz + hz), Vector3(cx - hx, y1, cz + hz), Vector3.UP, type)
	if face_x:
		_quad(Vector3(cx + hx, y0, cz - hz), Vector3(cx + hx, y0, cz + hz), Vector3(cx + hx, y1, cz + hz), Vector3(cx + hx, y1, cz - hz), Vector3.RIGHT, type)
	if face_z:
		_quad(Vector3(cx - hx, y0, cz + hz), Vector3(cx + hx, y0, cz + hz), Vector3(cx + hx, y1, cz + hz), Vector3(cx - hx, y1, cz + hz), Vector3.BACK, type)
	if face_x:
		_quad(Vector3(cx - hx, y0, cz - hz), Vector3(cx - hx, y0, cz + hz), Vector3(cx - hx, y1, cz + hz), Vector3(cx - hx, y1, cz - hz), Vector3.LEFT, type)
	if face_z:
		_quad(Vector3(cx - hx, y0, cz - hz), Vector3(cx + hx, y0, cz - hz), Vector3(cx + hx, y1, cz - hz), Vector3(cx - hx, y1, cz - hz), Vector3.FORWARD, type)


func _vertex(p: Vector3, n: Vector3, type: int) -> void:
	_positions.append(p)
	_normals.append(n)
	_colors.append(Color(float(type) / GlyphSurfaceType.TYPE_DIV, float(_edge_bits) / EDGE_DIV, 1.0 if _under_wall else (FREE_STANDING if _free_standing else 0.0), 1.0))
	_uvs.append(Vector2(_cell))


## Quad with outward normal n, wound clockwise seen from outside (Godot's front face).
func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, type: int) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var tmp: Vector3 = b
		b = d
		d = tmp
	var corners: Array[Vector3] = [a, b, c, d]
	for i in QUAD_ORDER:
		_vertex(corners[i], n, type)


## Triangle whose outward normal points away from `inside`.
func _tri(a: Vector3, b: Vector3, c: Vector3, inside: Vector3, type: int) -> void:
	var n: Vector3 = (b - a).cross(c - a).normalized()
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		n = -n
	if (b - a).cross(c - a).dot(n) > 0.0:
		var tmp: Vector3 = b
		b = c
		c = tmp
	for p in [a, b, c]:
		_vertex(p, n, type)
