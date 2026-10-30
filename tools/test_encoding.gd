extends SceneTree
## Test pattern for the data-encoded 3D buffer (docs/visual_direction.md, performance and risk
## notes). Draws quads with known material id / luminance / state through the real encoding
## functions, reads the rendered pixels back and decodes them exactly like the post shader does.
## Needs a GPU (the headless renderer draws nothing), so it is NOT part of the headless suite:
##   godot --path . --resolution 1280x720 -s tools/test_encoding.gd
## Prints "PASS test_encoding" or "FAIL ..." plus the worst decode errors.

const SHADER := "res://tools/test_encoding_pattern.gdshader"
# Mirrors of world_encoding.gdshaderinc.
const ID_BASE := 0.25
const ID_STEP := 0.045
const L_BASE := 0.2
const L_RANGE := 0.8
const LIVE_BASE := 0.2
const LIVE_RANGE := 0.25
const T_MIN := -0.3
const T_MAX := 1.0
const MEMORY_THRESHOLD := 0.475
## Allowed decode error: luminance 1/64 (a quarter of a ramp step at 8 steps is far larger),
## palette offset and memory amount 0.03 (the residual toe near 0.2 gives the worst case).
const L_TOLERANCE := 0.016
const T_TOLERANCE := 0.03
const COLUMNS := 21

var _frames: int = 0
var _cam: Camera3D
var _cases: Array[Dictionary] = []
var _shader: Shader


func _init() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP test_encoding (the headless renderer draws nothing; run it with a GPU, see header)")
		quit(0)
		return
	process_frame.connect(_tick)
	_shader = load(SHADER) as Shader
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 14.0
	root.add_child(_cam)
	_cam.rotation_degrees = Vector3(-90, 0, 0)
	_cam.position = Vector3(COLUMNS * 0.5, 5.0, 4.0)
	var row := 0
	for id in range(1, 6):
		for i in COLUMNS:
			_add({"id": id, "l": i / float(COLUMNS - 1), "mode": 0, "v": 0.2}, i, row)
		row += 1
	for i in COLUMNS:
		_add({"id": 1, "l": 0.5, "mode": 0, "v": T_MIN + (T_MAX - T_MIN) * i / float(COLUMNS - 1)}, i, row)
	row += 1
	for i in COLUMNS:
		_add({"id": 4, "l": 0.5, "mode": 1, "v": i / float(COLUMNS - 1)}, i, row)


func _add(c: Dictionary, col: int, row: int) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.8, 0.8)
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("material_id", c.id)
	mat.set_shader_parameter("lum", c.l)
	mat.set_shader_parameter("state_mode", c.mode)
	mat.set_shader_parameter("value", c.v)
	q.material = mat
	m.mesh = q
	m.rotation_degrees = Vector3(-90, 0, 0)
	m.position = Vector3(col + 0.5, 0.0, row + 0.5)
	root.add_child(m)
	c["pos"] = m.position
	_cases.append(c)


func _tick() -> void:
	_frames += 1
	if _frames < 6:
		return
	var img: Image = root.get_texture().get_image()
	var worst_l := 0.0
	var worst_t := 0.0
	var worst_m := 0.0
	var fails: PackedStringArray = []
	for c in _cases:
		var p: Vector2 = _cam.unproject_position(c.pos)
		var px: Color = img.get_pixel(int(p.x), int(p.y))
		var id: int = 0 if px.r < ID_BASE - 0.5 * ID_STEP else int(floor((px.r - ID_BASE) / ID_STEP + 0.5))
		var l: float = clampf((px.g - L_BASE) / L_RANGE, 0.0, 1.0)
		if id != c.id:
			fails.append("id %d decoded as %d (r=%.4f)" % [c.id, id, px.r])
		worst_l = maxf(worst_l, absf(l - c.l))
		if absf(l - c.l) > L_TOLERANCE:
			fails.append("id %d luminance %.3f decoded as %.3f" % [c.id, c.l, l])
		var is_mem: bool = px.b >= MEMORY_THRESHOLD
		if is_mem != (c.mode == 1):
			fails.append("state mode %d decoded as memory=%s (b=%.4f)" % [c.mode, is_mem, px.b])
		elif c.mode == 0:
			var t: float = T_MIN + clampf((px.b - LIVE_BASE) / LIVE_RANGE, 0.0, 1.0) * (T_MAX - T_MIN)
			worst_t = maxf(worst_t, absf(t - c.v))
			if c.id == 1 and c.l == 0.5 and absf(t - c.v) > T_TOLERANCE:
				fails.append("palette offset %.3f decoded as %.3f" % [c.v, t])
		else:
			var m: float = clampf((px.b - 0.5) * 2.0, 0.0, 1.0)
			worst_m = maxf(worst_m, absf(m - c.v))
			if absf(m - c.v) > T_TOLERANCE:
				fails.append("memory %.3f decoded as %.3f" % [c.v, m])
	print("cases %d, worst luminance error %.4f, worst palette-offset error %.4f, worst memory error %.4f" % [_cases.size(), worst_l, worst_t, worst_m])
	if fails.is_empty():
		print("PASS test_encoding")
		quit(0)
	else:
		for f in fails.slice(0, 12):
			printerr("FAIL: ", f)
		print("FAIL test_encoding")
		quit(1)
