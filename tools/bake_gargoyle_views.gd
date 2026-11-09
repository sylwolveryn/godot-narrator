extends SceneTree
## Offline baker of the gargoyle fountain statue (task-101). The statue is modelled here as a signed distance field
## (crouching winged gargoyle on a pedestal, open mouth pouring a water arc into the basin), ray-marched on the CPU
## with an orthographic camera at the game's isometric pitch from VIEWS yaws, and turned into ASCII art: per art cell
## the shaded brightness picks the glyph from a density ramp and the light that dominates picks the colour layer
## (stone shadow / stone / moonlit stone / basin-lit cyan rim / red eyes / water). The result is a LargeObjectViews
## resource that LargeObjectView shows on a camera-facing billboard (the basin is real geometry, see FountainBasin).
## Nothing here runs in the game: the runtime only swaps pre-built texts when the camera yaw crosses a view boundary.
##   godot --headless --max-fps 30 --path . -s tools/bake_gargoyle_views.gd
## Units: one footprint cell = 1.0; y up; the gargoyle faces +z; the base centre (0, 0, 0) is the footprint centre.

const OUT := "res://resources/config/large_objects/gargoyle_views.tres"
## Coarse bake for small fountains (a 1x1 statue would show the fine bake in unreadably small glyphs).
const OUT_SMALL := "res://resources/config/large_objects/gargoyle_views_small.tres"
const COLS_SMALL := 22
const VIEWS := 16
const PITCH := -35.264
## Art columns across the widest view and the glyph cell aspect (row height / column width) of the art font.
const COLS := 36
const GLYPH_ASPECT := 2.12
## Sub-samples per art cell (vertical, horizontal): glyph cells are tall, so two rows of two.
const SUB_V := 2
const SUB_H := 2
const MAX_STEPS := 64
const HIT_EPS := 0.0015
const FAR := 6.0
const NORMAL_EPS := 0.003

## Material ids.
const M_STONE := 0
const M_EYE := 1
const M_WATER := 2

## Density ramp of the stone glyphs, dark to bright (index 0 is never drawn: a hit always draws something).
## Distinct from the floor glyphs (0 o + ;), so the statue never blends into the ground.
const RAMP := " .:+xX#M"
const WATER_GLYPH := "|"
## Silhouette cells (2x2 sub-sample hit pattern, bit = row * 2 + column, top-left first) draw a line glyph along the
## edge instead of a density glyph, so the outline reads like hand-made ASCII art.
const EDGE_GLYPHS := {
	0b0011: "-", 0b1100: "_", 0b0101: "|", 0b1010: "|",
	0b0001: "/", 0b1000: "/", 0b0111: "/", 0b1110: "/",
	0b0010: "\\", 0b0100: "\\", 0b1011: "\\", 0b1101: "\\",
}
const EYE_GLYPH := "@"
const SPLASH_GLYPH := "*"
## Water surface of the basin in model units (LargeObjectDef.basin_water_height / statue_scale): whatever of the statue
## lies below it is under water, so its cells stay empty (no art, no backing) and the real water shows.
const WATER_Y := 0.125
## Water hits below this height are the splash on the surface (own layer, own glyphs).
const SPLASH_TOP := 0.26

## Model bounds (conservative), used for the image extent and the ray clip.
const BOX_MIN := Vector3(-0.8, 0.0, -0.40)
const BOX_MAX := Vector3(0.8, 1.6, 0.45)

## Lighting: a cold key light fixed to the CAMERA (upper left of the screen, so every view shows the form the same way),
## the glowing basin from below (object space), a weak camera rim. Brightness is raised to CONTRAST for a dark body
## with bright highlights, like the concept.
const KEY_DIR := Vector3(-0.55, 0.75, 0.6)   # (screen right, screen up, towards the camera)
const MOON_GAIN := 0.95
const AMBIENT := 0.05
const CONTRAST := 1.6
const POOL_Y := 0.18
const POOL_GAIN := 0.95
const POOL_FALLOFF := 0.9
const SPLASH := Vector3(0.0, 0.2, 0.34)
## The creature model sits this much lower than modelled (pedestal height).
const CREATURE_DROP := 0.12
const SPLASH_GAIN := 0.55
const SPLASH_RADIUS := 0.55
const RIM_GAIN := 0.22
## Brightness bands of the stone layers; above RIM_SHARE of the light coming from the basin the cell is cyan.
const BAND_DARK := 0.22
const BAND_MID := 0.5
const RIM_SHARE := 0.4
const RIM_MIN := 0.14
## Connected art pieces smaller than this many cells are dropped (thin edge-on membranes leave loose fragments).
const MIN_FRAGMENT := 6

var _right := Vector3.ZERO
var _up := Vector3.ZERO
var _back := Vector3.ZERO


func _init() -> void:
	var ok: bool = _bake(COLS, OUT) and _bake(COLS_SMALL, OUT_SMALL)
	quit(0 if ok else 1)


func _bake(cols: int, path: String) -> bool:
	var t0: int = Time.get_ticks_msec()
	var views := LargeObjectViews.new()
	views.pitch_degrees = PITCH
	# Shared image extent over all views (so the anchor is the same in every view).
	var u_min: float = INF
	var u_max: float = -INF
	var v_min: float = INF
	var v_max: float = -INF
	for k in VIEWS:
		_set_camera(k)
		for i in 8:
			var c := Vector3(BOX_MAX.x if i & 1 else BOX_MIN.x, BOX_MAX.y if i & 2 else BOX_MIN.y, BOX_MAX.z if i & 4 else BOX_MIN.z)
			u_min = minf(u_min, c.dot(_right))
			u_max = maxf(u_max, c.dot(_right))
			v_min = minf(v_min, c.dot(_up))
			v_max = maxf(v_max, c.dot(_up))
	# Symmetric around the anchor horizontally (the label is centred on it).
	var half_u: float = maxf(-u_min, u_max)
	var col_w: float = 2.0 * half_u / cols
	var row_h: float = col_w * GLYPH_ASPECT
	var rows: int = int(ceil((v_max - v_min) / row_h))
	views.col_width = col_w
	views.row_height = row_h
	views.anchor = Vector2(half_u / col_w, v_max / row_h)
	views.front_depth = 0.24
	var arts := PackedStringArray()
	var masks := PackedStringArray()
	for k in VIEWS:
		_set_camera(k)
		var art := PackedStringArray()
		var mask := PackedStringArray()
		for r in rows:
			var line: String = ""
			var mline: String = ""
			for c in cols:
				var cell: Array = _shade_cell(-half_u + c * col_w, v_max - r * row_h, col_w, row_h)
				line += cell[0]
				mline += cell[1]
			art.append(line.rstrip(" "))
			mask.append(mline.rstrip(" "))
		_drop_fragments(art, mask)
		arts.append("\n".join(art))
		masks.append("\n".join(mask))
	views.arts = arts
	views.masks = masks
	var err: int = ResourceSaver.save(views, path)
	print("baked %d views %dx%d in %d ms -> %s (%s)" % [VIEWS, cols, rows, Time.get_ticks_msec() - t0, path, error_string(err)])
	for k in OS.get_cmdline_user_args():
		print(arts[int(k)])
	return err == OK


## Clears every 8-connected piece of art smaller than MIN_FRAGMENT cells (in place; the row count stays).
func _drop_fragments(art: PackedStringArray, mask: PackedStringArray) -> void:
	var seen: Dictionary = {}
	for r in art.size():
		for c in art[r].length():
			if art[r][c] == " " or seen.has(Vector2i(c, r)):
				continue
			var piece: Array[Vector2i] = []
			var stack: Array[Vector2i] = [Vector2i(c, r)]
			seen[Vector2i(c, r)] = true
			while not stack.is_empty():
				var at: Vector2i = stack.pop_back()
				piece.append(at)
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var n := Vector2i(at.x + dx, at.y + dy)
						if n.y < 0 or n.y >= art.size() or n.x < 0 or n.x >= art[n.y].length():
							continue
						if art[n.y][n.x] != " " and not seen.has(n):
							seen[n] = true
							stack.append(n)
			if piece.size() < MIN_FRAGMENT:
				for at in piece:
					var line: String = art[at.y]
					art[at.y] = line.substr(0, at.x) + " " + line.substr(at.x + 1)
					var m: String = mask[at.y]
					if at.x < m.length():
						mask[at.y] = m.substr(0, at.x) + " " + m.substr(at.x + 1)


func _set_camera(k: int) -> void:
	var yaw: float = deg_to_rad(360.0 * k / VIEWS)
	var p: float = deg_to_rad(PITCH)
	_right = Vector3(cos(yaw), 0.0, -sin(yaw))
	_up = Vector3(sin(p) * sin(yaw), cos(p), sin(p) * cos(yaw))
	_back = Vector3(cos(p) * sin(yaw), -sin(p), cos(p) * cos(yaw))


## [glyph, layer] of the art cell whose top-left is (u, v) on the image plane.
func _shade_cell(u: float, v: float, w: float, h: float) -> Array:
	var hits: int = 0
	var lum_sum: float = 0.0
	var pool_sum: float = 0.0
	var mats: Array[int] = [0, 0, 0]
	var pattern: int = 0
	for sy in SUB_V:
		for sx in SUB_H:
			var su: float = u + (sx + 0.5) * w / SUB_H
			var sv: float = v - (sy + 0.5) * h / SUB_V
			var res: Vector4 = _trace(_right * su + _up * sv + _back * FAR, -_back)
			if res.x < 0.0:
				continue
			hits += 1
			pattern |= 1 << (sy * SUB_H + sx)
			mats[int(res.y)] += 1
			lum_sum += res.z
			pool_sum += res.w
	var total: int = SUB_V * SUB_H
	if hits * 4 < total:
		return [" ", " "]
	var coverage: float = float(hits) / total
	var lum: float = lum_sum / hits
	var pool: float = pool_sum / hits
	if mats[M_EYE] > 0:
		return [EYE_GLYPH, "e"]
	if mats[M_WATER] * 2 >= hits:
		return [SPLASH_GLYPH, "s"] if lum_sum / hits < 0.75 else [WATER_GLYPH, "w"]
	lum *= lerpf(0.65, 1.0, coverage)
	var idx: int = clampi(1 + int(sqrt(lum) * (RAMP.length() - 1)), 1, RAMP.length() - 1)
	var glyph: String = EDGE_GLYPHS.get(pattern, RAMP[idx])
	if EDGE_GLYPHS.has(pattern) and pool <= RIM_MIN:
		return [glyph, "c"]
	var layer: String = "a"
	if pool > RIM_MIN and pool >= lum * RIM_SHARE:
		layer = "r"
	elif lum >= BAND_MID:
		layer = "c"
	elif lum >= BAND_DARK:
		layer = "b"
	return [glyph, layer]


## x: distance along the ray or -1 (miss), y: material, z: stone brightness 0..1, w: basin light 0..1.
func _trace(origin: Vector3, dir: Vector3) -> Vector4:
	var span: Vector2 = _clip(origin, dir)
	if span.x > span.y:
		return Vector4(-1.0, 0.0, 0.0, 0.0)
	var t: float = span.x
	for i in MAX_STEPS:
		var p: Vector3 = origin + dir * t
		var d: Vector2 = _sdf(p)
		if d.x < HIT_EPS:
			if p.y < WATER_Y:
				return Vector4(-1.0, 0.0, 0.0, 0.0)
			return _light(p, dir, int(d.y), t)
		t += d.x
		if t > span.y:
			break
	return Vector4(-1.0, 0.0, 0.0, 0.0)


func _clip(o: Vector3, d: Vector3) -> Vector2:
	var t0: float = 0.0
	var t1: float = FAR * 3.0
	for a in 3:
		if absf(d[a]) < 1e-6:
			if o[a] < BOX_MIN[a] or o[a] > BOX_MAX[a]:
				return Vector2(1.0, 0.0)
			continue
		var ta: float = (BOX_MIN[a] - o[a]) / d[a]
		var tb: float = (BOX_MAX[a] - o[a]) / d[a]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
	return Vector2(t0, t1)


func _light(p: Vector3, dir: Vector3, mat: int, t: float) -> Vector4:
	if mat == M_WATER:
		return Vector4(t, mat, 0.5 if p.y < SPLASH_TOP else 1.0, 1.0)
	if mat != M_STONE:
		return Vector4(t, mat, 1.0, 1.0)
	var e := Vector3(NORMAL_EPS, 0.0, 0.0)
	var n := Vector3(
		_sdf(p + e).x - _sdf(p - e).x,
		_sdf(p + Vector3(0.0, NORMAL_EPS, 0.0)).x - _sdf(p - Vector3(0.0, NORMAL_EPS, 0.0)).x,
		_sdf(p + Vector3(0.0, 0.0, NORMAL_EPS)).x - _sdf(p - Vector3(0.0, 0.0, NORMAL_EPS)).x).normalized()
	var key: Vector3 = (_right * KEY_DIR.x + _up * KEY_DIR.y + _back * KEY_DIR.z).normalized()
	var moon: float = maxf(n.dot(key), 0.0) * MOON_GAIN
	# The glowing basin: light from below, stronger close to the water.
	var below: float = maxf(-n.y * 0.6 + 0.4, 0.0)
	var near_pool: float = exp(-maxf(p.y - POOL_Y, 0.0) * POOL_FALLOFF)
	var to_splash: Vector3 = SPLASH - p
	var splash: float = maxf(n.dot(to_splash.normalized()), 0.0) * maxf(1.0 - to_splash.length() / SPLASH_RADIUS, 0.0) * SPLASH_GAIN
	var pool: float = below * near_pool * POOL_GAIN * 0.5 + splash
	var rim: float = pow(1.0 - absf(n.dot(dir)), 3.0) * RIM_GAIN
	var lum: float = pow(clampf(AMBIENT + moon + rim + pool * 0.5, 0.0, 1.0), CONTRAST)
	return Vector4(t, mat, lum, clampf(pool, 0.0, 1.0))


# --- the model -------------------------------------------------------------------------------------------------------

## x: distance, y: material.
func _sdf(p: Vector3) -> Vector2:
	# Pedestal: a low block with a ledge under the claws.
	var d: float = _round_box(p, Vector3(0.0, 0.17, -0.02), Vector3(0.15, 0.17, 0.15), 0.015)
	d = minf(d, _round_box(p, Vector3(0.0, 0.355, -0.01), Vector3(0.19, 0.025, 0.19), 0.01))
	d = minf(d, _round_box(p, Vector3(0.0, 0.03, -0.02), Vector3(0.19, 0.03, 0.19), 0.01))
	var floor_p: Vector3 = p
	# The creature sits CREATURE_DROP lower than it is modelled (on the low pedestal).
	p += Vector3(0.0, CREATURE_DROP, 0.0)
	var q := Vector3(absf(p.x), p.y, p.z)   # mirrored for the paired parts
	# Crouching body.
	var body: float = _ellipsoid(p, Vector3(0.0, 0.76, -0.04), Vector3(0.2, 0.25, 0.17))
	body = _smin(body, _ellipsoid(p, Vector3(0.0, 0.8, 0.05), Vector3(0.15, 0.15, 0.12)), 0.06)
	body = _smin(body, _sphere(q, Vector3(0.14, 0.6, -0.02), 0.12), 0.06)
	body = _smin(body, _ellipsoid(q, Vector3(0.12, 0.505, 0.11), Vector3(0.055, 0.035, 0.085)), 0.03)
	# Arms: shoulder -> elbow -> hand gripping the ledge.
	var arm: float = _capsule(q, Vector3(0.17, 0.93, 0.0), Vector3(0.24, 0.72, 0.08), 0.06, 0.05)
	arm = _smin(arm, _capsule(q, Vector3(0.24, 0.72, 0.08), Vector3(0.14, 0.52, 0.16), 0.05, 0.04), 0.03)
	arm = minf(arm, _ellipsoid(q, Vector3(0.13, 0.5, 0.18), Vector3(0.05, 0.03, 0.06)))
	body = _smin(body, arm, 0.04)
	# Neck and head.
	body = _smin(body, _capsule(p, Vector3(0.0, 0.9, 0.0), Vector3(0.0, 1.02, 0.07), 0.09, 0.08), 0.05)
	var head: float = _sphere(p, Vector3(0.0, 1.09, 0.1), 0.165)
	head = _smin(head, _ellipsoid(p, Vector3(0.0, 1.0, 0.24), Vector3(0.12, 0.085, 0.11)), 0.04)
	head = _smin(head, _capsule(q, Vector3(0.0, 1.16, 0.23), Vector3(0.12, 1.165, 0.2), 0.04, 0.03), 0.02)
	# Fangs.
	head = minf(head, _capsule(q, Vector3(0.05, 0.99, 0.31), Vector3(0.05, 0.95, 0.315), 0.012, 0.004))
	# Open mouth.
	head = maxf(head, -_round_box(p, Vector3(0.0, 0.985, 0.32), Vector3(0.06, 0.016, 0.09), 0.005))
	body = _smin(body, head, 0.04)
	# Horns (curving back) and ears.
	var horn: float = _capsule(q, Vector3(0.08, 1.2, 0.08), Vector3(0.21, 1.36, 0.0), 0.055, 0.035)
	horn = minf(horn, _capsule(q, Vector3(0.21, 1.36, 0.0), Vector3(0.19, 1.56, -0.12), 0.035, 0.01))
	horn = minf(horn, _capsule(q, Vector3(0.14, 1.11, 0.06), Vector3(0.29, 1.18, 0.02), 0.032, 0.006))
	body = _smin(body, horn, 0.015)
	d = minf(d, body)
	# Wings: two membranes behind the shoulders with a scalloped lower edge and a bone along the top.
	var tip := Vector3(0.74, 1.46, -0.26)
	var low := Vector3(0.64, 0.6, -0.2)
	var wing: float = _triangle(q, Vector3(0.12, 1.02, -0.13), tip, low) - 0.02
	wing = minf(wing, _triangle(q, Vector3(0.12, 1.02, -0.13), low, Vector3(0.12, 0.68, -0.14)) - 0.02)
	for s in 3:
		var f: float = 0.22 + 0.27 * s
		var edge: Vector3 = tip.lerp(low, f) + Vector3(0.11, -0.03, 0.0)
		wing = maxf(wing, -_sphere(q, edge, 0.12))
	wing = minf(wing, _capsule(q, Vector3(0.15, 1.02, -0.12), tip, 0.035, 0.012))
	wing = minf(wing, _capsule(q, Vector3(0.52, 1.33, -0.24), Vector3(0.58, 0.72, -0.17), 0.03, 0.012))
	wing = minf(wing, _capsule(q, Vector3(0.36, 1.21, -0.2), Vector3(0.36, 0.68, -0.13), 0.028, 0.012))
	d = minf(d, wing)
	var out := Vector2(d, M_STONE)
	# Eyes (sunk in the brow).
	var eye: float = _sphere(q, Vector3(0.068, 1.115, 0.245), 0.036)
	if eye < out.x:
		out = Vector2(eye, M_EYE)
	# Water: an arc from the mouth into the basin, and its splash.
	var water: float = INF
	var prev := Vector3(0.0, 0.985, 0.33)
	for i in range(1, 7):
		var s: float = i / 6.0
		var next := Vector3(0.0, 0.985 - 0.8 * s * s, 0.33 + 0.01 * s)
		water = minf(water, _capsule(p, prev, next, 0.04 + 0.012 * s, 0.04 + 0.012 * (i + 1) / 6.0))
		prev = next
	water = minf(water, _ellipsoid(floor_p, SPLASH - Vector3(0.0, 0.04, 0.0), Vector3(0.11, 0.07, 0.11)))
	if water < out.x:
		out = Vector2(water, M_WATER)
	return out


static func _sphere(p: Vector3, c: Vector3, r: float) -> float:
	return (p - c).length() - r


static func _ellipsoid(p: Vector3, c: Vector3, r: Vector3) -> float:
	var q: Vector3 = (p - c) / r
	var k0: float = q.length()
	var k1: float = (q / r).length()
	return k0 * (k0 - 1.0) / maxf(k1, 1e-6)


static func _capsule(p: Vector3, a: Vector3, b: Vector3, ra: float, rb: float) -> float:
	var pa: Vector3 = p - a
	var ba: Vector3 = b - a
	var h: float = clampf(pa.dot(ba) / ba.dot(ba), 0.0, 1.0)
	return (pa - ba * h).length() - lerpf(ra, rb, h)


static func _round_box(p: Vector3, c: Vector3, b: Vector3, r: float) -> float:
	var q: Vector3 = (p - c).abs() - b
	return Vector3(maxf(q.x, 0.0), maxf(q.y, 0.0), maxf(q.z, 0.0)).length() + minf(maxf(q.x, maxf(q.y, q.z)), 0.0) - r


static func _smin(a: float, b: float, k: float) -> float:
	var h: float = clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, h) - k * h * (1.0 - h)


## Unsigned distance to a triangle (Inigo Quilez).
static func _triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var ba: Vector3 = b - a
	var pa: Vector3 = p - a
	var cb: Vector3 = c - b
	var pb: Vector3 = p - b
	var ac: Vector3 = a - c
	var pc: Vector3 = p - c
	var nor: Vector3 = ba.cross(ac)
	var outside: float = signf(ba.cross(nor).dot(pa)) + signf(cb.cross(nor).dot(pb)) + signf(ac.cross(nor).dot(pc))
	if outside < 2.0:
		var e1: Vector3 = ba * clampf(ba.dot(pa) / ba.dot(ba), 0.0, 1.0) - pa
		var e2: Vector3 = cb * clampf(cb.dot(pb) / cb.dot(cb), 0.0, 1.0) - pb
		var e3: Vector3 = ac * clampf(ac.dot(pc) / ac.dot(ac), 0.0, 1.0) - pc
		return sqrt(minf(minf(e1.dot(e1), e2.dot(e2)), e3.dot(e3)))
	return sqrt(nor.dot(pa) * nor.dot(pa) / nor.dot(nor))
