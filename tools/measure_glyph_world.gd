extends SceneTree
## Dev tool (task-031): measures draw calls, primitives, GPU render time and FPS of the glyph-surface world on the
## main scene (needs a GPU, NOT headless). Two cases: "opening" (spawn, reveal radius 2) and "worst" (wide reveal
## radius next to spikes, items and corruption: the most revealed, most lit surface on screen).
##   printf '[display]\nwindow/size/viewport_width=1920\nwindow/size/viewport_height=1080\nwindow/size/mode=0\n' > override.cfg
##   godot --path . --max-fps 30 -s tools/measure_glyph_world.gd; rm override.cfg
## Pass "-- grown" to measure with the grown entity (task-017). Prints "PERF <case> ..." lines.

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "measure_glyph_world"
const WARMUP := 150
## Frame at which "-- menu" opens the in-world menu (after the intro; the opening glyph flight ends well before WARMUP).
const MENU_FRAME := 60
const SAMPLES := 300
## Length of the storm of "-- storm" (covers the warm-up and both cases).
const STORM_SECONDS := 40.0
const WIDE_RADIUS := 8.0
const WORST_CELL := Vector2i(25, 3)

var _frame: int = 0
var _main: Node
var _case: String = "opening"
var _phase_start: int = 0
var _times: PackedFloat64Array = PackedFloat64Array()
var _gpu: PackedFloat64Array = PackedFloat64Array()
var _draws: PackedFloat64Array = PackedFloat64Array()
var _prims: PackedFloat64Array = PackedFloat64Array()
var _last: int = 0


func _init() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	var save_path: String = Support.isolate_save(_main, SAVE_TAG)
	if OS.get_cmdline_user_args().has("menu"):
		# Measure with the in-world menu open (task-018): menu unlocked, entity unlocked, Tab pressed once the run runs.
		var menu_seed := PersistentProgress.new()
		menu_seed.identity_glyph = "Q"
		menu_seed.run_count = 3
		menu_seed.death_count = 3
		menu_seed.menu_unlocked = true
		menu_seed.entity_unlocked = true
		menu_seed.entity_grow_played = true
		menu_seed.entity_form = String(EntityForm.GROWN)
		ResourceSaver.save(menu_seed, save_path)
	elif OS.get_cmdline_user_args().has("grown"):
		# Measure with the grown multi-glyph entity (task-017): a temporary save with the entity unlocked and active.
		var seeded := PersistentProgress.new()
		seeded.identity_glyph = "Q"
		seeded.run_count = 3
		seeded.death_count = 3
		seeded.entity_unlocked = true
		seeded.entity_grow_played = true
		seeded.entity_form = String(EntityForm.GROWN)
		ResourceSaver.save(seeded, save_path)
	var intro := IntroConfig.new()
	intro.black_hold = 0.1
	intro.wave_fade_in = 0.1
	intro.wave_hold = 0.1
	intro.reveal_duration = 0.2
	_main.get_node("IntroSequence").set("config", intro)
	root.add_child(_main)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	process_frame.connect(_tick)


func _tick() -> void:
	_frame += 1
	if _frame == MENU_FRAME and OS.get_cmdline_user_args().has("storm"):
		# Glyph storm (task-030): one long storm that spans the whole measurement.
		var storm_player: Node3D = _main.get_node("Player")
		root.get_node("SignalBus").emit_signal("glyph_storm_requested", storm_player.global_position, 0.0, STORM_SECONDS, Color(0, 0, 0, 0))
	if _frame == MENU_FRAME and OS.get_cmdline_user_args().has("menu"):
		for pressed in [true, false]:
			var tab := InputEventKey.new()
			tab.physical_keycode = KEY_TAB
			tab.pressed = pressed
			Input.parse_input_event(tab)
	var local: int = _frame - _phase_start
	var now: int = Time.get_ticks_usec()
	if local > WARMUP and local <= WARMUP + SAMPLES:
		_times.append((now - _last) / 1000.0)
		_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	_last = now
	if local == WARMUP + SAMPLES:
		_report()
		if _case == "worst":
			Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
			quit()
			return
		_case = "worst"
		_phase_start = _frame
		_times.clear()
		_gpu.clear()
		_draws.clear()
		_prims.clear()
		var reveal: Node = _main.get_node("MapReveal")
		var cfg: RevealConfig = (reveal.get("config") as RevealConfig).duplicate()
		cfg.reveal_radius = WIDE_RADIUS
		reveal.set("config", cfg)
		var loader: MapLoader = _main.get_node("World/MapLoader")
		var player: CharacterBody3D = _main.get_node("Player")
		player.velocity = Vector3.ZERO
		player.global_position = loader.cell_to_world(WORST_CELL)


func _mean(a: PackedFloat64Array) -> float:
	var m: float = 0.0
	for v in a:
		m += v / a.size()
	return m


func _report() -> void:
	var sorted: PackedFloat64Array = _times.duplicate()
	sorted.sort()
	var g: PackedFloat64Array = _gpu.duplicate()
	g.sort()
	var size: Vector2i = root.get_visible_rect().size
	var mean: float = _mean(_times)
	print("PERF %s %dx%d frames=%d draw_calls=%.1f primitives=%.0f" % [_case, size.x, size.y, SAMPLES, _mean(_draws), _mean(_prims)])
	print("PERF %s frame ms: mean %.2f p99 %.2f max %.2f (%.1f FPS)" % [_case, mean, sorted[int(sorted.size() * 0.99)], sorted[-1], 1000.0 / mean])
	print("PERF %s gpu ms: mean %.2f median %.2f p99 %.2f max %.2f" % [_case, _mean(_gpu), g[g.size() / 2], g[int(g.size() * 0.99)], g[-1]])
