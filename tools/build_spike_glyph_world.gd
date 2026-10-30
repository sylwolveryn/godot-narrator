extends SceneTree
## SPIKE A (task-027, throwaway). Builds res://scenes/spikes/glyph_world/glyph_world.tscn from a slice of the M1 map.
## Run tools/build_spike_glyph_atlas.gd first (needs a renderer, see its header), then:
##   godot --headless --path . -s tools/build_spike_glyph_world.gd
## The world is ONE merged ArrayMesh with ONE ShaderMaterial (type id in vertex COLOR.r), one merged halo mesh, a player quad pair.

const MAP_PATH := "res://data/maps/m1_awakening.txt"
const SCENE_PATH := "res://scenes/spikes/glyph_world/glyph_world.tscn"
const ATLAS_PATH := "res://scenes/spikes/glyph_world/glyph_atlas.png"
const SHADER_DIR := "res://scenes/spikes/glyph_world/"
## Slice around the spawn (20,12): north room with items/spikes/corruption, corridor, spawn room. 16 x 12 cells.
const SLICE := Rect2i(12, 2, 16, 12)
const WALL_H := 1.0
const T_WALL := 0
const T_FLOOR := 1
const T_SPIKES := 2
const T_CORRUPT := 3
const T_ITEM := 4
const TYPE_DIV := 8.0
const ITEM_HALF := 0.16
const ITEM_H := 0.95
const SPIKE_HALF := 0.13
const SPIKE_H := 0.38
const CAM_SIZE := 12.6
const CAM_DIST := 30.0
const CAM_PITCH := -35.264
const CAM_YAW := 45.0
const HALO_QUAD_ORDER: Array[int] = [0, 1, 2, 1, 3, 2]
## Path in map cell coordinates (cell centre = +0.5). Avoids item (14,2),(27,2), spike and corruption cells.
const PATH_CELLS: Array[Vector2] = [
	Vector2(20.5, 12.5), Vector2(20.0, 9.5), Vector2(20.0, 4.5), Vector2(13.5, 4.5), Vector2(13.5, 2.5), Vector2(13.5, 4.5),
	Vector2(25.5, 4.5), Vector2(25.5, 2.5), Vector2(25.5, 4.5), Vector2(20.0, 4.5), Vector2(20.0, 9.5), Vector2(14.5, 11.5),
	Vector2(25.5, 11.5), Vector2(20.5, 12.5),
]

var _map: MapData
var _origin: Vector2
var _st: SurfaceTool
var _halo: SurfaceTool
var _tri_count: int = 0
var _halo_count: int = 0
var _static_lights: Array[Vector4] = []
var _static_light_cols: Array[Vector4] = []


func _init() -> void:
	process_frame.connect(_build, CONNECT_ONE_SHOT)


func _build() -> void:
	var loader := MapLoader.new()
	_map = loader.load_file(MAP_PATH)
	loader.free()
	_origin = Vector2(SLICE.position) + Vector2(SLICE.size) * 0.5

	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_halo = SurfaceTool.new()
	_halo.begin(Mesh.PRIMITIVE_TRIANGLES)
	_geometry()
	var world_mesh: ArrayMesh = _st.commit()
	var halo_mesh: ArrayMesh = _halo.commit()
	print("SPIKE world mesh: %d triangles, %d vertices; halo mesh %d quads" % [_tri_count, _tri_count * 3, _halo_count])

	var atlas_img := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	atlas_img.convert(Image.FORMAT_L8)
	atlas_img.generate_mipmaps()
	var atlas := ImageTexture.create_from_image(atlas_img)

	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_DIR + "glyph_surface.gdshader")
	mat.set_shader_parameter("glyph_atlas", atlas)
	mat.set_shader_parameter("wall_height", WALL_H)
	mat.set_shader_parameter("slice_params", Vector4(0.0, 0.0, SLICE.size.x * 0.5 + 0.5, SLICE.size.y * 0.5 + 0.5))

	var root := Node3D.new()
	root.name = "GlyphWorld"
	root.set_script(load(SHADER_DIR + "glyph_world.gd"))

	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CAM_SIZE
	cam.near = 1.0
	cam.far = 80.0
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.01, 0.018)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	cam.environment = env
	var basis := Basis.from_euler(Vector3(deg_to_rad(CAM_PITCH), deg_to_rad(CAM_YAW), 0.0))
	cam.transform = Transform3D(basis, basis * Vector3(0, 0, CAM_DIST) + Vector3(0, 0.6, 0))
	_add(root, cam)

	var world := MeshInstance3D.new()
	world.name = "WorldMesh"
	world.mesh = world_mesh
	world.material_override = mat
	world.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(root, world)

	var halo_mat := ShaderMaterial.new()
	halo_mat.shader = load(SHADER_DIR + "glyph_halo.gdshader")
	var halos := MeshInstance3D.new()
	halos.name = "StaticHalos"
	halos.mesh = halo_mesh
	halos.material_override = halo_mat
	halos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halos.extra_cull_margin = 4.0
	_add(root, halos)

	var player := Node3D.new()
	player.name = "Player"
	_add(root, player)
	var pq := QuadMesh.new()
	pq.size = Vector2(1, 1)
	var p_halo_mat := ShaderMaterial.new()
	p_halo_mat.shader = load(SHADER_DIR + "glyph_halo.gdshader")
	p_halo_mat.set_shader_parameter("base_size", 1.7)
	p_halo_mat.set_shader_parameter("tint", Color(1.0, 0.85, 0.4, 0.55))
	var p_halo := MeshInstance3D.new()
	p_halo.name = "Halo"
	p_halo.mesh = pq
	p_halo.material_override = p_halo_mat
	p_halo.sorting_offset = 1.0
	p_halo.extra_cull_margin = 4.0
	p_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(player, p_halo)
	var gq := QuadMesh.new()
	gq.size = Vector2(0.62, 0.95)
	var g_mat := ShaderMaterial.new()
	g_mat.shader = load(SHADER_DIR + "glyph_marker.gdshader")
	g_mat.set_shader_parameter("glyph_atlas", atlas)
	var glyph := MeshInstance3D.new()
	glyph.name = "Glyph"
	glyph.mesh = gq
	glyph.material_override = g_mat
	glyph.extra_cull_margin = 2.0
	glyph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(player, glyph)

	var pts := PackedVector3Array()
	for c in PATH_CELLS:
		pts.append(Vector3(c.x - _origin.x, 0.0, c.y - _origin.y))
	root.set("path_points", pts)
	root.set("world_material", mat)
	root.set("static_light_pos", PackedVector4Array(_static_lights))
	root.set("static_light_col", PackedVector4Array(_static_light_cols))

	var probe := Node.new()
	probe.name = "SpikeProbe"
	probe.set_script(load(SHADER_DIR + "spike_probe.gd"))
	_add(root, probe)

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, SCENE_PATH)
	print("SPIKE saved %s err=%d" % [SCENE_PATH, err])
	quit(0 if err == OK else 1)


func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = parent if parent.get_parent() == null else parent.owner


# --- geometry -----------------------------------------------------------------------------------------------------------

func _type_at(c: Vector2i) -> StringName:
	if not SLICE.has_point(c):
		return MapLegend.VOID
	return _map.type_at(c)


func _w(c: Vector2i, y: float = 0.0) -> Vector3:
	return Vector3(float(c.x) - _origin.x, y, float(c.y) - _origin.y)


func _cell_center(c: Vector2i) -> Vector3:
	return _w(c) + Vector3(0.5, 0.0, 0.5)


func _hash(c: Vector2i, salt: float = 0.0) -> float:
	return fposmod(sin(float(c.x) * 12.9898 + float(c.y) * 78.233 + salt * 37.719) * 43758.5453, 1.0)


func _geometry() -> void:
	for y in range(SLICE.position.y, SLICE.end.y):
		for x in range(SLICE.position.x, SLICE.end.x):
			var c := Vector2i(x, y)
			var t: StringName = _map.type_at(c)
			var o: Vector3 = _w(c)
			match t:
				MapLegend.WALL:
					_wall(c)
				MapLegend.FLOOR, MapLegend.SPAWN:
					_floor_quad(o, T_FLOOR)
				MapLegend.SPIKES:
					_floor_quad(o, T_SPIKES)
					_spikes(o)
					_add_halo(o + Vector3(0.5, 0.3, 0.5), 0.95, Color(1.0, 0.30, 0.14, 0.6))
				MapLegend.CORRUPT:
					_floor_quad(o, T_CORRUPT)
					_corruption(c, o)
					_add_halo(o + Vector3(0.5, 0.25, 0.5), 1.0, Color(0.75, 0.22, 1.0, 0.30))
				MapLegend.ITEM:
					_floor_quad(o, T_FLOOR)
					var ctr: Vector3 = _cell_center(c)
					_box(ctr.x, ctr.z, 0.0, ITEM_H, ITEM_HALF, ITEM_HALF, T_ITEM, true, true)
					_add_halo(ctr + Vector3(0, 0.7, 0), 1.1, Color(0.30, 0.80, 1.0, 0.5))
					_add_halo(ctr + Vector3(0, 0.4, 0), 2.7, Color(0.10, 0.35, 0.75, 0.28))
					_static_lights.append(Vector4(ctr.x, 0.9, ctr.z, 4.6))
					_static_light_cols.append(Vector4(0.25, 0.65, 1.0, 1.0) * 1.1)
	# strip / patch lights (spikes: two strips, corruption: one patch)
	_light_for(Vector2i(15, 3), Vector2i(17, 3), Color(1.0, 0.35, 0.18), 3.4, 0.5)
	_light_for(Vector2i(23, 3), Vector2i(24, 3), Color(1.0, 0.35, 0.18), 3.4, 0.5)
	_light_for(Vector2i(26, 3), Vector2i(27, 4), Color(0.75, 0.25, 1.0), 4.4, 0.6)


func _light_for(a: Vector2i, b: Vector2i, col: Color, radius: float, h: float) -> void:
	var p: Vector3 = (_w(a) + _w(b)) * 0.5 + Vector3(0.5, h, 0.5)
	_static_lights.append(Vector4(p.x, p.y, p.z, radius))
	_static_light_cols.append(Vector4(col.r, col.g, col.b, 1.0))


func _floor_quad(o: Vector3, type: int) -> void:
	_quad(o, o + Vector3(1, 0, 0), o + Vector3(1, 0, 1), o + Vector3(0, 0, 1), Vector3.UP, type)


func _wall(c: Vector2i) -> void:
	var o: Vector3 = _w(c)
	_box(o.x + 0.5, o.z + 0.5, 0.0, WALL_H, 0.5, 0.5, T_WALL,
			_type_at(c + Vector2i(1, 0)) != MapLegend.WALL, _type_at(c + Vector2i(0, 1)) != MapLegend.WALL)


## Box with a top and only the +x / +z faces (the only side faces the iso camera can see).
func _box(cx: float, cz: float, y0: float, y1: float, hx: float, hz: float, type: int, face_x: bool, face_z: bool) -> void:
	_quad(Vector3(cx - hx, y1, cz - hz), Vector3(cx + hx, y1, cz - hz), Vector3(cx + hx, y1, cz + hz), Vector3(cx - hx, y1, cz + hz), Vector3.UP, type)
	if face_x:
		_quad(Vector3(cx + hx, y0, cz - hz), Vector3(cx + hx, y0, cz + hz), Vector3(cx + hx, y1, cz + hz), Vector3(cx + hx, y1, cz - hz), Vector3.RIGHT, type)
	if face_z:
		_quad(Vector3(cx - hx, y0, cz + hz), Vector3(cx + hx, y0, cz + hz), Vector3(cx + hx, y1, cz + hz), Vector3(cx - hx, y1, cz + hz), Vector3.BACK, type)


func _spikes(o: Vector3) -> void:
	for sx in 2:
		for sz in 2:
			var base := Vector3(o.x + 0.27 + 0.46 * sx, 0.0, o.z + 0.27 + 0.46 * sz)
			var apex := base + Vector3(0, SPIKE_H, 0)
			var corners: Array[Vector3] = [
				base + Vector3(-SPIKE_HALF, 0, -SPIKE_HALF), base + Vector3(SPIKE_HALF, 0, -SPIKE_HALF),
				base + Vector3(SPIKE_HALF, 0, SPIKE_HALF), base + Vector3(-SPIKE_HALF, 0, SPIKE_HALF)]
			for i in 4:
				_tri(corners[i], corners[(i + 1) % 4], apex, base, T_SPIKES)


func _corruption(c: Vector2i, o: Vector3) -> void:
	for sx in 2:
		for sz in 2:
			var cell := Vector2i(c.x * 2 + sx, c.y * 2 + sz)
			if _hash(cell) < 0.25:
				continue
			var hh: float = 0.12 + 0.55 * _hash(cell, 1.0) * _hash(cell, 2.0)
			_box(o.x + 0.25 + 0.5 * sx, o.z + 0.25 + 0.5 * sz, 0.0, hh, 0.19, 0.19, T_CORRUPT, true, true)


func _vertex(st: SurfaceTool, p: Vector3, n: Vector3, type: int) -> void:
	st.set_color(Color(float(type) / TYPE_DIV, 0, 0, 1))
	st.set_normal(n)
	st.add_vertex(p)


## Quad with outward normal n; wound clockwise seen from outside (Godot front face).
func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, type: int) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var tmp := b
		b = d
		d = tmp
	for p in [a, b, c, a, c, d]:
		_vertex(_st, p, n, type)
	_tri_count += 2


## Triangle whose outward normal points away from `inside`.
func _tri(a: Vector3, b: Vector3, c: Vector3, inside: Vector3, type: int) -> void:
	var n: Vector3 = (b - a).cross(c - a).normalized()
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		n = -n
	if (b - a).cross(c - a).dot(n) > 0.0:
		var tmp := b
		b = c
		c = tmp
	for p in [a, b, c]:
		_vertex(_st, p, n, type)
	_tri_count += 1


## One billboard quad: all four vertices sit at the centre, the shader expands them (corner in UV, size/phase in UV2).
func _add_halo(center: Vector3, size: float, col: Color) -> void:
	var phase: float = center.x * 1.7 + center.z * 2.3
	for i in HALO_QUAD_ORDER:
		_halo.set_color(col)
		_halo.set_uv(Vector2(i & 1, (i >> 1) & 1))
		_halo.set_uv2(Vector2(size, phase))
		_halo.add_vertex(center)
	_halo_count += 1
