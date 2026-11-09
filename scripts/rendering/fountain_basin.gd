class_name FountainBasin
extends RefCounted
## Geometry of a fountain basin (task-101): a stone rim (four boxes) around a water quad, fitted to a footprint and
## centred on it, standing on the floor (y = 0). Faces that look into the basin get COLOR.r = 1, the water COLOR.g = 1
## (shaders/fountain_basin.gdshader). Built once per fountain on map build; nothing changes at run time.

const SHADER := "res://shaders/fountain_basin.gdshader"
const ATLAS := "res://resources/glyphs/glyph_atlas.png"


## The basin mesh of a footprint `size` (world units, x by z) for a def whose basin sizes are in multiples of `unit`.
static func build_mesh(size: Vector2, unit: float, def: LargeObjectDef) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx: float = size.x * 0.5 - def.basin_inset * unit
	var hz: float = size.y * 0.5 - def.basin_inset * unit
	var w: float = def.basin_rim_width * unit
	var h: float = def.basin_rim_height * unit
	# Rim: north / south span the full width, west / east fill between them.
	_box(st, Vector3(-hx, 0.0, -hz), Vector3(hx, h, -hz + w), Vector3(0.0, 0.0, 1.0))
	_box(st, Vector3(-hx, 0.0, hz - w), Vector3(hx, h, hz), Vector3(0.0, 0.0, -1.0))
	_box(st, Vector3(-hx, 0.0, -hz + w), Vector3(-hx + w, h, hz - w), Vector3(1.0, 0.0, 0.0))
	_box(st, Vector3(hx - w, 0.0, -hz + w), Vector3(hx, h, hz - w), Vector3(-1.0, 0.0, 0.0))
	# Corner posts (outer faces only look outwards).
	if def.basin_post_size > 0.0 and def.basin_post_height > 0.0:
		var ps: float = w * def.basin_post_size
		var ph: float = h * def.basin_post_height
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var cx: float = sx * (hx - ps * 0.5)
				var cz: float = sz * (hz - ps * 0.5)
				_box(st, Vector3(cx - ps * 0.5, 0.0, cz - ps * 0.5), Vector3(cx + ps * 0.5, ph, cz + ps * 0.5), Vector3.ZERO)
	# Water.
	var y: float = def.basin_water_height * unit
	_quad(st, Vector3(-hx + w, y, -hz + w), Vector3(hx - w, y, -hz + w), Vector3(hx - w, y, hz - w), Vector3(-hx + w, y, hz - w),
		Vector3.UP, Color(0.0, 1.0, 0.0))
	return st.commit()


## The basin material of a def (one per fountain: its tint carries the reveal look).
static func make_material(def: LargeObjectDef, unit: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER) as Shader
	m.set_shader_parameter(&"glyph_atlas", load(ATLAS) as Texture2D)
	m.set_shader_parameter(&"glyph_cell", def.basin_glyph_cell * unit)
	m.set_shader_parameter(&"stone_dark", def.basin_stone_dark)
	m.set_shader_parameter(&"stone_bright", def.basin_stone_bright)
	m.set_shader_parameter(&"water_deep", def.basin_water_deep)
	m.set_shader_parameter(&"water_bright", def.basin_water_bright)
	m.set_shader_parameter(&"rim_height", def.basin_rim_height * unit)
	m.set_shader_parameter(&"lip_color", def.basin_lip_color)
	m.set_shader_parameter(&"splash", Vector2(0.0, def.basin_splash * unit))
	return m


## An axis-aligned box from `lo` to `hi`; the side whose normal equals `inward` is marked as looking into the basin,
## and so is the top (it catches the water's glow). The bottom is left out (it stands on the floor).
static func _box(st: SurfaceTool, lo: Vector3, hi: Vector3, inward: Vector3) -> void:
	var inner := Color(1.0, 0.0, 0.0)
	var outer := Color(0.0, 0.0, 0.0)
	_quad(st, Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3.UP,
		outer if inward == Vector3.ZERO else inner)
	var sides: Array = [
		[Vector3(0.0, 0.0, 1.0), Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)],
		[Vector3(0.0, 0.0, -1.0), Vector3(hi.x, lo.y, lo.z), Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z)],
		[Vector3(1.0, 0.0, 0.0), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z)],
		[Vector3(-1.0, 0.0, 0.0), Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, hi.y, lo.z)],
	]
	for s: Array in sides:
		var n: Vector3 = s[0]
		_quad(st, s[1], s[2], s[3], s[4], n, inner if n == inward else outer)


## Quad a-b-c-d, counter-clockwise seen from the side `n` points to.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, color: Color) -> void:
	# Godot's front faces are clockwise; flip when the winding faces away from n.
	var flip: bool = (b - a).cross(c - a).dot(n) > 0.0
	var tri: PackedVector3Array = PackedVector3Array([a, c, b, a, d, c] if flip else [a, b, c, a, c, d])
	for v in tri:
		st.set_color(color)
		st.set_normal(n)
		st.add_vertex(v)
