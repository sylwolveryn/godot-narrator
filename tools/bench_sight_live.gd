extends SceneTree
## Benchmark (not a test): frame cost of the real game while the player walks, for comparing sight scales (task-098
## --sight) after the sight performance pass. Prints the camera view reach the light shadows are limited to and the
## average / worst process and physics time per frame while walking.
##   godot --path . --max-fps 30 --resolution 1280x720 -s tools/bench_sight_live.gd -- --map=m5_shapes --sight=1000 [--overlay]
## `--overlay` also shows the narration debug overlay (task-020.07) to measure its cost.

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "bench_sight_live"
## Frames: walking starts after the intro, one key per leg, measured until the end.
const WALK_START := 150
const LEG_FRAMES := 60
const LEGS: PackedStringArray = ["D", "S", "A", "W", "D", "S"]

var _frame: int = 0
var _main: Node
var _held: Key = KEY_NONE
var _proc := PackedFloat64Array()
var _phys := PackedFloat64Array()


func _init() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	Support.isolate_save(_main, SAVE_TAG)
	var intro := IntroConfig.new()
	intro.black_hold = 0.1
	intro.wave_fade_in = 0.1
	intro.wave_hold = 0.1
	intro.reveal_duration = 0.2
	_main.get_node("IntroSequence").set("config", intro)
	root.add_child(_main)
	if OS.get_cmdline_user_args().has("--overlay"):
		var overlay: CanvasLayer = (load("res://scripts/ui/narration_debug_overlay.gd") as GDScript).new()
		root.add_child(overlay)
		overlay.call("set_active", true)
		print("narration debug overlay on")
	process_frame.connect(_tick)


func _tick() -> void:
	_frame += 1
	var into: int = _frame - WALK_START
	if into < 0:
		return
	var leg: int = into / LEG_FRAMES
	if into % LEG_FRAMES == 0:
		if _held != KEY_NONE:
			_send(_held, false)
		if leg >= LEGS.size():
			_report()
			return
		_held = OS.find_keycode_from_string(LEGS[leg])
		_send(_held, true)
	_proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)


func _report() -> void:
	var view: Node = _find_view(_main)
	if view != null:
		var pos: Vector3 = _main.get_node("Player").global_position
		print("view reach %.1f cells, light radius %.1f cells" % [view.call("_view_reach_cells", pos), view.call("player_light_radius")])
	var wm: MeshInstance3D = _main.get_node("World/MapLoader").get("world_mesh")
	if wm != null and wm.mesh != null:
		var verts: int = 0
		for i in wm.mesh.get_surface_count():
			verts += wm.mesh.surface_get_array_len(i)
		print("world mesh: %d surfaces, %d vertices, one node (culled as a whole)" % [wm.mesh.get_surface_count(), verts])
	print("draw calls %d, primitives %d" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	print("sight %s: process avg %.2f ms worst %.2f ms | physics avg %.2f ms worst %.2f ms" % [
		RunMods.current().sight_scale, _avg(_proc), _max(_proc), _avg(_phys), _max(_phys)])
	Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
	quit()


func _find_view(n: Node) -> Node:
	if n.get_script() == load("res://scripts/rendering/glyph_world_view.gd"):
		return n
	for c in n.get_children():
		var f: Node = _find_view(c)
		if f != null:
			return f
	return null


static func _avg(a: PackedFloat64Array) -> float:
	var s: float = 0.0
	for v in a:
		s += v
	return s / maxf(float(a.size()), 1.0)


static func _max(a: PackedFloat64Array) -> float:
	var m: float = 0.0
	for v in a:
		m = maxf(m, v)
	return m


func _send(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)
