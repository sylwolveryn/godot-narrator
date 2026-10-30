extends Node3D
## Spike B (TASK-028): glyph-object "morph" moments. Throwaway prototype, isolated in this folder.
## Every glyph in the scene is one instance of ONE MultiMesh (see glyph_morph_field.gd). A morph is many
## glyph objects flying, spinning and reassembling into a new formation; a glyph may switch character
## mid-flight (flip). Moments: 1 hero grows, 2 surroundings become a menu, 3 narration assembles,
## 4 stress storm (every glyph moves at once).
##
## Run: godot --path . --max-fps 30 res://scenes/spikes/glyph_morph/glyph_morph.tscn
## User args (after --): moment=1..4 (loop only that one) count=N (ground glyphs) cpu hud=0 perf quit=SEC seed=N

const GlyphSet := preload("res://scenes/spikes/glyph_morph/glyph_set.gd")

# --- camera / world -------------------------------------------------------------------------------
const CAM_PITCH_DEG: float = -35.264
const CAM_YAW_DEG: float = 45.0
const CAM_ORTHO_SIZE: float = 10.5
const CAM_DISTANCE: float = 40.0
const CAM_TARGET := Vector3(0.0, 3.0, 0.0)
const GROUND_Y: float = 0.08
const GROUND_BASE_COUNT: int = 676
const GROUND_BASE_SPACING: float = 0.7
const GROUND_BASE_SIZE: float = 0.4
const GROUND_CHARS: String = "..,,'`:;.·"
const GROUND_COL_A := Color(0.16, 0.30, 0.38)
const GROUND_COL_B := Color(0.34, 0.58, 0.66)
const WALL_COLUMNS: int = 6
const WALL_STACK: int = 3
const WALL_START := Vector3(3.2, 0.0, -3.0)
const WALL_STEP: float = 0.7
const WALL_Y0: float = 0.3
const WALL_DY: float = 0.55
const WALL_SIZE: float = 0.62
const WALL_COL := Color(0.42, 0.52, 0.80)
const HERO_POS := Vector3(0.0, 0.4, 0.0)
const HERO_SIZE: float = 0.95
const HERO_COL := Color(1.0, 0.78, 0.30)

# --- formations -----------------------------------------------------------------------------------
const ENTITY_ART: PackedStringArray = [
	"  ^   ^  ",
	" ^#^^^#^ ",
	" (#####) ",
	" (O#@#O) ",
	" (#####) ",
	"  VV VV  ",
	"  || ||  ",
]
const ENTITY_ADV := Vector2(0.66, 0.74)
const ENTITY_SIZE: float = 0.78
const MENU_ITEMS: PackedStringArray = ["continue", "remember", "forget"]
const MENU_ADV: float = 0.62
const MENU_ROW: float = 1.35
const MENU_SIZE: float = 1.0
const MENU_FRAME_HALF := Vector2(3.9, 2.45)
const MENU_FRAME_STEP: float = 0.68
const MENU_FRAME_SIZE: float = 0.55
const MENU_CENTER_UP: float = 3.0
const NARRATION_LINES: PackedStringArray = ["I remember your voice.", "Or I invented it."]
const NARRATION_ADV: float = 0.66
const NARRATION_ROW: float = 1.5
const NARRATION_SIZE: float = 1.05
const NARRATION_CENTER_UP: float = 3.2

# --- timing (seconds) -----------------------------------------------------------------------------
const START_DELAY: float = 1.2
const GAP: float = 1.1
const GROW_DUR: float = 0.85
const GROW_STAGGER: float = 0.045
const GROW_HOLD: float = 2.2
const MENU_DUR: float = 0.9
const MENU_STAGGER: float = 0.03
const MENU_HOLD: float = 2.6
const NARR_DUR: float = 0.95
const NARR_STAGGER: float = 0.07
const NARR_HOLD: float = 3.4
const RETURN_DUR: float = 0.8
const RETURN_JITTER: float = 0.55
const JITTER: float = 0.12
const STORM_DUR: float = 1.4
const STORM_HOLD: float = 0.8
const STORM_RADIUS: float = 7.5

# --- colours --------------------------------------------------------------------------------------
const MENU_COL_ON := Color(1.0, 0.95, 0.72)
const MENU_COL_OFF := Color(0.62, 0.78, 0.95)
const MENU_FRAME_COL := Color(0.75, 0.62, 0.30)
const NARR_COL := Color(1.0, 0.93, 0.72)
const EYE_COL := Color(1.0, 0.80, 0.25)
const SPINS: PackedFloat32Array = [-1.0, 1.0, 2.0, -2.0, 0.0, 1.0]
const PERF_WARMUP_FRAMES: int = 90
const HUD_REFRESH: float = 0.25
const HITCH_SEC: float = 0.045

@onready var _camera: Camera3D = $Camera
@onready var _field: MultiMeshInstance3D = $Glyphs
@onready var _hud: Label = $Hud/Label

var _n: int = 0
var _ground_count: int = 0
var _home_pos: PackedVector3Array
var _home_glyph: PackedInt32Array
var _home_size: PackedFloat32Array
var _home_col: PackedColorArray
var _busy: PackedByteArray
var _rng := RandomNumberGenerator.new()
var _right: Vector3
var _up: Vector3
var _requested: int = 0
var _forced_moment: int = 0
var _moment_name: String = "idle"
var _args: Dictionary = {}
var _hud_timer: float = 0.0
var _perf: bool = false
var _frame: int = 0
var _quit_at: float = 0.0
var _stats: Dictionary = {
	"morph": [0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0],
	"idle": [0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0],
}


func _ready() -> void:
	_parse_args()
	_rng.seed = int(_args.get("seed", 7))
	_setup_input()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = CAM_ORTHO_SIZE
	_camera.rotation_degrees = Vector3(CAM_PITCH_DEG, CAM_YAW_DEG, 0.0)
	_camera.position = CAM_TARGET + _camera.basis.z * CAM_DISTANCE
	_camera.far = CAM_DISTANCE * 3.0
	_right = _camera.basis.x
	_up = _camera.basis.y
	_build_world(int(_args.get("count", GROUND_BASE_COUNT)))
	_field.set_cpu_mode(_args.has("cpu"))
	_hud.get_parent().visible = _args.get("hud", "1") != "0"
	_forced_moment = int(_args.get("moment", 0))
	_perf = _args.has("perf")
	_quit_at = float(_args.get("quit", 0.0))
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_run_loop()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", false, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"


func _setup_input() -> void:
	for m in [1, 2, 3, 4]:
		var action: StringName = StringName("spike_moment_%d" % m)
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventKey.new()
			ev.physical_keycode = (KEY_1 + (m - 1)) as Key
			InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	for m in [1, 2, 3, 4]:
		if event.is_action_pressed(StringName("spike_moment_%d" % m)):
			_requested = m


# --- world ----------------------------------------------------------------------------------------
func _build_world(ground_target: int) -> void:
	var side: int = maxi(4, int(round(sqrt(float(ground_target)))))
	var density: float = sqrt(float(GROUND_BASE_COUNT) / float(side * side))
	var spacing: float = GROUND_BASE_SPACING * density
	var gsize: float = GROUND_BASE_SIZE * clampf(density * 1.4, 0.2, 1.0)
	var wall_cells: int = WALL_COLUMNS * WALL_STACK
	_ground_count = side * side
	_n = 1 + _ground_count + wall_cells
	_field.setup(_n)
	_home_pos.resize(_n)
	_home_glyph.resize(_n)
	_home_size.resize(_n)
	_home_col.resize(_n)
	_busy.resize(_n)
	_home(0, HERO_POS, GlyphSet.index_of("@"), HERO_SIZE, HERO_COL, 1.0)
	var idx: int = 1
	var half: float = (side - 1) * 0.5
	for gx in side:
		for gz in side:
			var jitter := Vector3(_rng.randf_range(-0.12, 0.12), 0.0, _rng.randf_range(-0.12, 0.12)) * density
			var p := Vector3((gx - half) * spacing, GROUND_Y, (gz - half) * spacing) + jitter
			var ch: String = GROUND_CHARS[_rng.randi() % GROUND_CHARS.length()]
			var c: Color = GROUND_COL_A.lerp(GROUND_COL_B, _rng.randf())
			_home(idx, p, GlyphSet.index_of(ch), gsize, c, 0.0)
			idx += 1
	for wc in WALL_COLUMNS:
		for ws in WALL_STACK:
			var p := WALL_START + Vector3(wc * WALL_STEP, WALL_Y0 + ws * WALL_DY, 0.0)
			var wch: String = "#" if (ws + wc) % 2 == 0 else "█"
			_home(idx, p, GlyphSet.index_of(wch), WALL_SIZE, WALL_COL, 0.0)
			idx += 1
	_field.upload()


func _home(i: int, pos: Vector3, glyph: int, size: float, col: Color, glow: float) -> void:
	_home_pos[i] = pos
	_home_glyph[i] = glyph
	_home_size[i] = size
	_home_col[i] = col
	_field.place(i, pos, glyph, size, col, glow)


# --- sequencer ------------------------------------------------------------------------------------
func _run_loop() -> void:
	await _wait(START_DELAY)
	var next: int = 1
	while true:
		var m: int = _requested if _requested != 0 else (_forced_moment if _forced_moment != 0 else next)
		_requested = 0
		match m:
			1: await _moment_hero()
			2: await _moment_menu()
			3: await _moment_narration()
			4: await _moment_storm()
		next = (m % 3) + 1
		_moment_name = "idle"
		await _wait(GAP)


func _wait(sec: float) -> void:
	var t: float = 0.0
	while t < sec and _requested == 0:
		await get_tree().process_frame
		t += get_process_delta_time()


func _wait_morph() -> void:
	while not _field.morph_done():
		await get_tree().process_frame


func _hold(sec: float) -> void:
	var t: float = 0.0
	while t < sec:
		await get_tree().process_frame
		t += get_process_delta_time()


func _process(delta: float) -> void:
	var t0: int = Time.get_ticks_usec()
	_field.advance(delta)
	var busy_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	_frame += 1
	if _hud.get_parent().visible:
		_hud_timer += delta
		if _hud_timer >= HUD_REFRESH:
			_hud_timer = 0.0
			_hud.text = "%s   [1] hero  [2] menu  [3] narration  [4] storm\n%d glyphs, 1 MultiMesh  %s  %d fps" % [
				_moment_name, _n, "CPU-anim" if _field.cpu_mode else "GPU-anim", Engine.get_frames_per_second()]
	if _perf and _frame > PERF_WARMUP_FRAMES:
		_record(busy_ms, delta)
	if _quit_at > 0.0 and Time.get_ticks_msec() * 0.001 > _quit_at:
		if _perf:
			_report()
		get_tree().quit()


func _record(busy_ms: float, delta: float) -> void:
	var rid: RID = get_viewport().get_viewport_rid()
	var s: Array = _stats["idle" if _field.morph_done() else "morph"]
	s[0] += 1
	s[1] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	s[2] += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	s[3] += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	s[4] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	s[5] += busy_ms
	s[7] = maxf(s[7], delta * 1000.0)
	if delta > HITCH_SEC:
		s[8] += 1
	s[6] = maxf(s[6], Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)


func _report() -> void:
	var size: Vector2i = get_viewport().get_visible_rect().size
	for k in ["morph", "idle"]:
		var s: Array = _stats[k]
		var n: float = maxf(1.0, float(s[0]))
		print("PERF %s n=%d glyphs=%d res=%dx%d mode=%s draw=%.1f prim=%.0f gpu_ms=%.3f process_ms=%.3f field_ms=%.3f process_max_ms=%.1f frame_max_ms=%.1f hitches=%d" % [
			k, s[0], _n, size.x, size.y, "cpu" if _field.cpu_mode else "shader",
			s[1] / n, s[2] / n, s[3] / n, s[4] / n, s[5] / n, s[6], s[7], s[8]])


# --- helpers --------------------------------------------------------------------------------------
func _screen_pos(center: Vector3, x: float, y: float) -> Vector3:
	return center + _right * x + _up * y


func _hero_base() -> Vector3:
	return Vector3(HERO_POS.x, 0.0, HERO_POS.z)


## Nearest free glyphs (horizontal distance) to a point; marks them busy.
func _borrow_nearest(center: Vector3, k: int) -> PackedInt32Array:
	var pairs: Array = []
	for i in range(1, _n):
		if _busy[i] == 0:
			var d: Vector3 = _home_pos[i] - center
			pairs.append([d.x * d.x + d.z * d.z, i])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out := PackedInt32Array()
	for j in mini(k, pairs.size()):
		out.append(pairs[j][1])
		_busy[pairs[j][1]] = 1
	return out


func _borrow_random(k: int) -> PackedInt32Array:
	var ids := PackedInt32Array()
	while ids.size() < k:
		var i: int = 1 + _rng.randi() % (_n - 1)
		if _busy[i] == 0:
			_busy[i] = 1
			ids.append(i)
	return ids


## Orders ids by their screen-x so assigning them to x-sorted slots keeps flight paths from crossing.
func _sort_ids_by_x(ids: PackedInt32Array) -> PackedInt32Array:
	var pairs: Array = []
	for id in ids:
		pairs.append([_home_pos[id].dot(_right), id])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out := PackedInt32Array()
	for p in pairs:
		out.append(p[1])
	return out


func _sort_slots_by_x(slots: Array) -> Array:
	var s: Array = slots.duplicate()
	s.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["x"] < b["x"])
	return s


func _arc_for(from: Vector3, to: Vector3) -> float:
	return 0.9 + from.distance_to(to) * 0.12 + _rng.randf() * 0.6


func _spin() -> float:
	return SPINS[_rng.randi() % SPINS.size()]


## Flies the given glyphs from where they are to the given slots. slots: [{pos, glyph, size, col, glow, delay}]
func _fly_to_slots(ids: PackedInt32Array, slots: Array, dur: float) -> void:
	for k in ids.size():
		var s: Dictionary = slots[k]
		var from: Vector3 = _field.cur_pos[ids[k]]
		_field.morph_set(ids[k], s["pos"], s["glyph"], s["size"], s["col"], s["glow"],
			s["delay"] + _rng.randf() * JITTER, dur + _rng.randf() * JITTER, _spin(), _arc_for(from, s["pos"]))


func _fly_home(ids: PackedInt32Array, delay_base: float, delay_step: float, random_order: bool) -> void:
	for k in ids.size():
		var id: int = ids[k]
		var delay: float = delay_base + (_rng.randf() * RETURN_JITTER if random_order else delay_step * k)
		var from: Vector3 = _field.cur_pos[id]
		_field.morph_set(id, _home_pos[id], _home_glyph[id], _home_size[id], _home_col[id], 0.0,
			delay, RETURN_DUR + _rng.randf() * JITTER, _spin(), _arc_for(from, _home_pos[id]))
		_busy[id] = 0


func _slot(pos: Vector3, ch: String, size: float, col: Color, glow: float, delay: float) -> Dictionary:
	return {"pos": pos, "glyph": GlyphSet.index_of(ch), "size": size, "col": col, "glow": glow, "delay": delay, "x": pos.dot(_right)}


# --- moment 1: hero grows -------------------------------------------------------------------------
func _entity_colour(ch: String) -> Color:
	match ch:
		"#": return Color(0.25, 0.75, 0.92)
		"(", ")": return Color(0.55, 0.95, 1.0)
		"^": return Color(0.85, 1.0, 1.0)
		"O": return EYE_COL
		"@": return HERO_COL
	return Color(0.35, 0.62, 0.85)


func _moment_hero() -> void:
	_moment_name = "1 hero grows"
	var rows: int = ENTITY_ART.size()
	var cols: int = ENTITY_ART[0].length()
	var base: Vector3 = _hero_base()
	var slots: Array = []
	var heart: Dictionary = {}
	for r in rows:
		for c in cols:
			var ch: String = ENTITY_ART[r][c]
			if ch == " ":
				continue
			var x: float = (c - (cols - 1) * 0.5) * ENTITY_ADV.x
			var y: float = (rows - 1 - r) * ENTITY_ADV.y + 0.3
			var glow: float = 1.0 if (ch == "O" or ch == "@") else 0.3
			var s: Dictionary = _slot(_screen_pos(base, x, y), ch, ENTITY_SIZE, _entity_colour(ch), glow, 0.0)
			if ch == "@":
				heart = s
			else:
				slots.append(s)
	var heart_pos: Vector3 = heart["pos"]
	for s in slots:
		s["delay"] = heart_pos.distance_to(s["pos"]) * GROW_STAGGER * 2.0
	var ids: PackedInt32Array = _borrow_nearest(base, slots.size())
	slots = _sort_slots_by_x(slots)
	ids = _sort_ids_by_x(ids)
	_field.morph_begin()
	_field.morph_set(0, heart["pos"], heart["glyph"], ENTITY_SIZE, HERO_COL, 1.0, 0.0, GROW_DUR, 1.0, 1.2)
	_fly_to_slots(ids, slots, GROW_DUR)
	_field.morph_commit()
	await _wait_morph()
	await _hold(GROW_HOLD)
	_field.morph_begin()
	_field.morph_set(0, HERO_POS, _home_glyph[0], HERO_SIZE, HERO_COL, 1.0, 0.9, GROW_DUR, -1.0, 1.0)
	_fly_home(ids, 0.0, 0.0, true)
	_field.morph_commit()
	await _wait_morph()


# --- moment 2: surroundings -> menu ---------------------------------------------------------------
func _moment_menu() -> void:
	_moment_name = "2 surroundings -> menu"
	var base: Vector3 = _hero_base()
	var centre: Vector3 = base + _up * MENU_CENTER_UP
	var slots: Array = []
	var order: int = 0
	for r in MENU_ITEMS.size():
		var word: String = MENU_ITEMS[r]
		var y: float = (1 - r) * MENU_ROW
		var on: bool = r == 0
		var col: Color = MENU_COL_ON if on else MENU_COL_OFF
		for c in word.length():
			var x: float = (c - (word.length() - 1) * 0.5) * MENU_ADV
			slots.append(_slot(_screen_pos(centre, x, y), word[c], MENU_SIZE, col, 1.0 if on else 0.55, order * MENU_STAGGER))
			order += 1
	slots.append(_slot(_screen_pos(centre, -(4.0 * MENU_ADV + 0.9), MENU_ROW), ">", MENU_SIZE, MENU_COL_ON, 1.0, order * MENU_STAGGER))
	slots.append(_slot(_screen_pos(centre, 4.0 * MENU_ADV + 0.9, MENU_ROW), "<", MENU_SIZE, MENU_COL_ON, 1.0, order * MENU_STAGGER))
	var fh: Vector2 = MENU_FRAME_HALF
	var nx: int = int(round(fh.x * 2.0 / MENU_FRAME_STEP))
	var ny: int = int(round(fh.y * 2.0 / MENU_FRAME_STEP))
	for ix in range(nx + 1):
		var x: float = -fh.x + fh.x * 2.0 * ix / nx
		for edge in [-1.0, 1.0]:
			var corner: bool = ix == 0 or ix == nx
			slots.append(_slot(_screen_pos(centre, x, edge * fh.y), "+" if corner else "-", MENU_FRAME_SIZE, MENU_FRAME_COL, 0.4, order * MENU_STAGGER * 0.5))
	for iy in range(1, ny):
		var y: float = -fh.y + fh.y * 2.0 * iy / ny
		for edge in [-1.0, 1.0]:
			slots.append(_slot(_screen_pos(centre, edge * fh.x, y), "|", MENU_FRAME_SIZE, MENU_FRAME_COL, 0.4, order * MENU_STAGGER * 0.5))
	var ids: PackedInt32Array = _borrow_nearest(base, slots.size())
	slots = _sort_slots_by_x(slots)
	ids = _sort_ids_by_x(ids)
	_field.morph_begin()
	_fly_to_slots(ids, slots, MENU_DUR)
	_field.morph_commit()
	await _wait_morph()
	await _hold(MENU_HOLD)
	_field.morph_begin()
	_fly_home(ids, 0.0, 0.0, true)
	_field.morph_commit()
	await _wait_morph()


# --- moment 3: narration assembles ----------------------------------------------------------------
func _moment_narration() -> void:
	_moment_name = "3 narration assembles"
	var base: Vector3 = _hero_base()
	var centre: Vector3 = base + _up * NARRATION_CENTER_UP
	var slots: Array = []
	var order: int = 0
	for r in NARRATION_LINES.size():
		var line: String = NARRATION_LINES[r]
		var y: float = (0.5 - r) * NARRATION_ROW
		for c in line.length():
			var ch: String = line[c]
			if ch != " ":
				var x: float = (c - (line.length() - 1) * 0.5) * NARRATION_ADV
				slots.append(_slot(_screen_pos(centre, x, y), ch, NARRATION_SIZE, NARR_COL, 1.0, order * NARR_STAGGER))
			order += 1
	var ids: PackedInt32Array = _borrow_random(slots.size())
	_field.morph_begin()
	_fly_to_slots(ids, slots, NARR_DUR)
	_field.morph_commit()
	await _wait_morph()
	await _hold(NARR_HOLD)
	_field.morph_begin()
	_fly_home(ids, 0.0, 0.0, true)
	_field.morph_commit()
	await _wait_morph()


# --- moment 4: stress storm (every glyph moves) ---------------------------------------------------
func _moment_storm() -> void:
	_moment_name = "4 storm (all glyphs)"
	var base: Vector3 = _hero_base()
	var centre: Vector3 = base + _up * NARRATION_CENTER_UP
	var ids := PackedInt32Array()
	for i in range(1, _n):
		ids.append(i)
		_busy[i] = 1
	_field.morph_begin()
	for k in ids.size():
		var f: float = float(k) / float(ids.size())
		var ang: float = f * 37.7
		var rad: float = STORM_RADIUS * sqrt(f)
		var pos: Vector3 = _screen_pos(centre, cos(ang) * rad * 1.5, sin(ang) * rad * 0.7)
		var ch: String = GlyphSet.CHARS[1 + (k % (GlyphSet.CHARS.length() - 1))]
		var from: Vector3 = _field.cur_pos[ids[k]]
		_field.morph_set(ids[k], pos, GlyphSet.index_of(ch), 0.4, Color.from_hsv(f, 0.5, 1.0), 0.0,
			f * 0.4, STORM_DUR, _spin(), _arc_for(from, pos))
	_field.morph_commit()
	await _wait_morph()
	await _hold(STORM_HOLD)
	_field.morph_begin()
	_fly_home(ids, 0.0, 0.0, true)
	_field.morph_commit()
	await _wait_morph()
