extends SceneTree
## Dev tool: measures frame time and GPU render time of the main scene (needs a GPU, NOT headless).
## The player stands next to spikes, an item and a corrupting patch (worst case for the shader).
##   printf '[display]\nwindow/size/viewport_width=1920\nwindow/size/viewport_height=1080\nwindow/size/mode=0\n' > override.cfg
##   godot --path . -s tools/measure_perf.gd -- [novsync]; rm override.cfg
## Prints PERF lines: uncapped CPU+GPU frame time, GPU render time and the 60 FPS verdict.

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "measure_perf"
const WARMUP := 240
const SAMPLES := 300
const BUDGET_MS := 16.6

var _frame: int = 0
var _main: Node
var _times: PackedFloat64Array = PackedFloat64Array()
var _gpu: PackedFloat64Array = PackedFloat64Array()
var _last: int = 0


func _init() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	if OS.get_cmdline_user_args().has("novsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	Support.isolate_save(_main, SAVE_TAG)
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
	if _frame == 120:
		var loader: MapLoader = _main.get_node("World/MapLoader")
		var player: CharacterBody3D = _main.get_node("Player")
		player.velocity = Vector3.ZERO
		player.global_position = loader.cell_to_world(Vector2i(25, 2))
	var now: int = Time.get_ticks_usec()
	if _frame > WARMUP and _frame <= WARMUP + SAMPLES:
		_times.append((now - _last) / 1000.0)
		_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	_last = now
	if _frame == WARMUP + SAMPLES:
		_report()


func _report() -> void:
	var sorted: PackedFloat64Array = _times.duplicate()
	sorted.sort()
	var gsorted: PackedFloat64Array = _gpu.duplicate()
	gsorted.sort()
	var mean: float = 0.0
	var gmean: float = 0.0
	for t in _times:
		mean += t / _times.size()
	for g in _gpu:
		gmean += g / _gpu.size()
	var size: Vector2i = root.get_visible_rect().size
	print("PERF %dx%d vsync=%s frames=%d" % [size.x, size.y, DisplayServer.window_get_vsync_mode(), SAMPLES])
	print("PERF frame ms: mean %.2f median %.2f p99 %.2f max %.2f  (mean %.0f FPS)" % [mean, sorted[sorted.size() / 2], sorted[int(sorted.size() * 0.99)], sorted[-1], 1000.0 / mean])
	print("PERF gpu render ms: mean %.2f median %.2f p99 %.2f max %.2f" % [gmean, gsorted[gsorted.size() / 2], gsorted[int(gsorted.size() * 0.99)], gsorted[-1]])
	print("PERF verdict: %s (budget %.1f ms)" % ["60 FPS held" if sorted[int(sorted.size() * 0.99)] <= BUDGET_MS * 1.05 else "OVER BUDGET", BUDGET_MS])
	Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
	quit()
