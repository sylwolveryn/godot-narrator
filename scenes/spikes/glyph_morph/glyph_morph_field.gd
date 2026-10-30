extends MultiMeshInstance3D
## Spike B: owns the ONE MultiMesh that draws every glyph quad and the per-instance morph data.
## Shader mode (default): a morph is written once into the instance buffer (start/end/timing per glyph);
## the vertex shader evaluates it from the single `morph_t` uniform. CPU cost per frame: one uniform.
## CPU mode (comparison only): GDScript evaluates the same curves for every moving glyph each frame
## and re-uploads the buffer.

const GlyphSet := preload("res://scenes/spikes/glyph_morph/glyph_set.gd")
const ATLAS_PATH := "res://scenes/spikes/glyph_morph/glyph_atlas.png"
const STRIDE: int = 20
const COLOUR_BITS: int = 31
const STATIC_DELAY: float = -1.0
const TAU_F: float = 6.2831853
const EASE_C1: float = 1.35
const EASE_C3: float = EASE_C1 + 1.0
const WOBBLE: float = 0.03
const POP: float = 0.45
const FLASH: float = 0.22
const AABB_HALF: float = 60.0
const QUAD_SIZE: float = 1.0

@export var glyph_material: ShaderMaterial
var cpu_mode: bool = false
var count: int = 0

# Current resting state (becomes the start of the next morph).
var cur_pos: PackedVector3Array
var cur_glyph: PackedFloat32Array
var cur_size: PackedFloat32Array
var cur_col: PackedColorArray
var cur_glow: PackedFloat32Array

var _buf: PackedFloat32Array
var _out: PackedFloat32Array
var _dirty: PackedInt32Array = PackedInt32Array()
var _morph_t: float = 100.0
var _morph_end: float = 0.0
var _mm: MultiMesh
var _active: PackedInt32Array = PackedInt32Array()
var _begin_us: int = 0
var _log_builds: bool = false


func setup(instance_count: int) -> void:
	count = instance_count
	var atlas_img: Image = (load(ATLAS_PATH) as Texture2D).get_image()
	atlas_img.generate_mipmaps()
	glyph_material.set_shader_parameter("atlas", ImageTexture.create_from_image(atlas_img))
	glyph_material.set_shader_parameter("atlas_grid", Vector2(GlyphSet.COLUMNS, GlyphSet.rows()))
	var quad := QuadMesh.new()
	quad.size = Vector2(QUAD_SIZE, QUAD_SIZE)
	quad.material = glyph_material
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.mesh = quad
	_mm.instance_count = count
	_mm.custom_aabb = AABB(Vector3(-AABB_HALF, -AABB_HALF, -AABB_HALF), Vector3.ONE * AABB_HALF * 2.0)
	multimesh = _mm
	cur_pos.resize(count)
	cur_glyph.resize(count)
	cur_size.resize(count)
	cur_col.resize(count)
	cur_glow.resize(count)
	_buf.resize(count * STRIDE)
	_out.resize(count * STRIDE)


func set_cpu_mode(on: bool) -> void:
	cpu_mode = on
	glyph_material.set_shader_parameter("cpu_mode", 1.0 if on else 0.0)
	glyph_material.set_shader_parameter("morph_t", 100.0)
	_morph_t = 100.0


## Sets an instance's resting state directly (used while building the world, before the first commit).
func place(i: int, pos: Vector3, glyph: int, size: float, col: Color, glow: float) -> void:
	cur_pos[i] = pos
	cur_glyph[i] = float(glyph)
	cur_size[i] = size
	cur_col[i] = col
	cur_glow[i] = glow
	_write_static(i)


func upload() -> void:
	_mm.buffer = _buf
	_out = _buf.duplicate()


func _colour_code(c: Color) -> float:
	var r: int = int(clampf(c.r, 0.0, 1.0) * COLOUR_BITS)
	var g: int = int(clampf(c.g, 0.0, 1.0) * COLOUR_BITS)
	var b: int = int(clampf(c.b, 0.0, 1.0) * COLOUR_BITS)
	var a: int = 1 if c.a > 0.5 else 0
	return float((r << 11) | (g << 6) | (b << 1) | a)


func _write(i: int, p0: Vector3, p1: Vector3, delay: float, dur: float, spin: float, arc: float,
		g0: float, g1: float, col1: Color, s0: float, s1: float, col0: Color, glow: float) -> void:
	var b: int = i * STRIDE
	_buf[b + 0] = p1.x
	_buf[b + 1] = delay
	_buf[b + 2] = arc
	_buf[b + 3] = p0.x
	_buf[b + 4] = p1.y
	_buf[b + 5] = dur
	_buf[b + 6] = g0
	_buf[b + 7] = p0.y
	_buf[b + 8] = p1.z
	_buf[b + 9] = spin
	_buf[b + 10] = g1
	_buf[b + 11] = p0.z
	_buf[b + 12] = col1.r
	_buf[b + 13] = col1.g
	_buf[b + 14] = col1.b
	_buf[b + 15] = col1.a
	_buf[b + 16] = s0
	_buf[b + 17] = s1
	_buf[b + 18] = _colour_code(col0)
	_buf[b + 19] = glow


func _write_static(i: int) -> void:
	_write(i, cur_pos[i], cur_pos[i], STATIC_DELAY, 0.001, 0.0, 0.0, cur_glyph[i], cur_glyph[i],
		cur_col[i], cur_size[i], cur_size[i], cur_col[i], cur_glow[i])


## Starts a new morph: everything that moved last time is frozen at its resting state first.
func morph_begin() -> void:
	_begin_us = Time.get_ticks_usec()
	_log_builds = OS.get_cmdline_user_args().has("perf")
	for k in _dirty.size():
		_write_static(_dirty[k])
	_dirty.clear()
	_active.clear()
	_morph_end = 0.0


## Adds one glyph to the current morph (target state + timing). Call between morph_begin and morph_commit.
func morph_set(i: int, pos: Vector3, glyph: int, size: float, col: Color, glow: float,
		delay: float, dur: float, spin: float, arc: float) -> void:
	_write(i, cur_pos[i], pos, delay, dur, spin, arc, cur_glyph[i], float(glyph), col,
		cur_size[i], size, cur_col[i], glow)
	cur_pos[i] = pos
	cur_glyph[i] = float(glyph)
	cur_size[i] = size
	cur_col[i] = col
	cur_glow[i] = glow
	_dirty.append(i)
	_active.append(i)
	_morph_end = maxf(_morph_end, delay + dur)


func morph_commit() -> void:
	_mm.buffer = _buf
	if _log_builds:
		print("BUILD_MS glyphs_moved=%d ms=%.2f" % [_active.size(), (Time.get_ticks_usec() - _begin_us) / 1000.0])
	if cpu_mode:
		_out = _buf.duplicate()
	_morph_t = 0.0
	glyph_material.set_shader_parameter("morph_t", 0.0)


func morph_done() -> bool:
	return _morph_t >= _morph_end


func advance(delta: float) -> void:
	_morph_t += delta
	if cpu_mode:
		if _morph_t <= _morph_end + delta:
			_cpu_update()
	else:
		glyph_material.set_shader_parameter("morph_t", _morph_t)


func _cpu_update() -> void:
	var t: float = _morph_t
	var time: float = Time.get_ticks_msec() * 0.001
	var out: PackedFloat32Array = _out
	var src: PackedFloat32Array = _buf
	for k in _active.size():
		var i: int = _active[k]
		var b: int = i * STRIDE
		var delay: float = src[b + 1]
		var dur: float = maxf(src[b + 5], 0.001)
		var u: float = clampf((t - delay) / dur, 0.0, 1.0)
		var us: float = u * u * (3.0 - 2.0 * u)
		var y: float = us - 1.0
		var e: float = 1.0 + EASE_C3 * y * y * y + EASE_C1 * y * y
		var lift: float = sin(PI * u)
		var arc: float = src[b + 2]
		var seed: float = fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		var a: float = seed * TAU_F
		var p0x: float = src[b + 3]
		var p0y: float = src[b + 7]
		var p0z: float = src[b + 11]
		var px: float = lerpf(p0x, src[b], e) + cos(a) * arc * 0.45 * lift
		var py: float = lerpf(p0y, src[b + 4], e) + arc * lift
		var pz: float = lerpf(p0z, src[b + 8], e) + sin(a) * arc * 0.45 * lift
		py += sin(time * 2.3 + seed * 40.0) * WOBBLE * smoothstep(0.92, 1.0, u)
		var g0: float = src[b + 6]
		var g1: float = src[b + 10]
		var glyph: float = g0
		var flip: float = 1.0
		if absf(g0 - g1) > 0.5:
			var f: float = smoothstep(0.2, 0.8, u)
			glyph = g0 if f < 0.5 else g1
			flip = maxf(absf(cos(PI * f)), 0.04)
		var size: float = lerpf(src[b + 16], src[b + 17], us) * (1.0 + POP * lift)
		out[b] = 0.0
		out[b + 1] = flip
		out[b + 2] = 0.0
		out[b + 3] = px
		out[b + 4] = 0.0
		out[b + 5] = 0.0
		out[b + 6] = glyph
		out[b + 7] = py
		out[b + 8] = 0.0
		out[b + 9] = src[b + 9] * TAU_F * us
		out[b + 10] = 0.0
		out[b + 11] = pz
		var k2: float = smoothstep(0.1, 0.9, u)
		var fl: float = FLASH * lift
		out[b + 12] = src[b + 12] + fl
		out[b + 13] = src[b + 13] + fl
		out[b + 14] = src[b + 14] + fl
		out[b + 15] = src[b + 15] * k2 + (1.0 - k2) * 1.0
		out[b + 16] = size
		out[b + 17] = size
		out[b + 18] = src[b + 18]
		out[b + 19] = src[b + 19]
	_mm.buffer = out
