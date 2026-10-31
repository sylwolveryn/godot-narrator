extends SceneTree
## Dev capture autopilot for the entity growth visuals (task-017; NOT part of the normal boot path). Seeds a temporary
## save at death_count = threshold - 1 (identity from the "glyph=" user arg, default "Q"), kills the first run so the
## entity unlocks, then records: the grow moment, the grown entity walking, erosion and death of the grown entity.
## The real save is never touched. Movie Maker capture:
##   tools/capture_at_size.sh 1366x768 <dir> 380 tools/capture_entity_growth.gd -- glyph=Q
## Prints "RUNSTART <frame>" for the grown run; capture frames are relative to it (see the offsets below).

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "capture_entity_growth"
const KILL_FRAME := 45
const WIDE_RADIUS := 8.0
## Offsets from the start of the run that grows the entity (frames at 30 fps).
const WALK_START := 125
const WALK_STOP := 150
const ERODE_AT := 165

var _frame: int = 0
var _run_start: int = -1
var _main: Node
var _player: CharacterBody3D
var _loader: MapLoader
var _held: Key = KEY_NONE
var _glyph: String = "Q"


func _init() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("glyph="):
			_glyph = a.get_slice("=", 1)
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	var path: String = Support.isolate_save(_main, SAVE_TAG)
	var seeded := PersistentProgress.new()
	seeded.identity_glyph = _glyph
	seeded.run_count = 2
	seeded.death_count = 2
	ResourceSaver.save(seeded, path)
	var intro := IntroConfig.new()
	intro.black_hold = 0.1
	intro.wave_fade_in = 0.1
	intro.wave_hold = 0.1
	intro.reveal_duration = 0.2
	_main.get_node("IntroSequence").set("config", intro)
	var run_cfg: RunConfig = (_main.get_node("RunManager").get("config") as RunConfig).duplicate()
	run_cfg.restart_delay = 0.6
	_main.get_node("RunManager").set("config", run_cfg)
	_player = _main.get_node("Player")
	_loader = _main.get_node("World/MapLoader")
	root.add_child(_main)
	var bus: Node = root.get_node("SignalBus")
	bus.connect("run_started", func(i: int) -> void:
		print("EVENT run_started %d frame %d" % [i, _frame])
		if i >= 1 and _run_start < 0:
			_run_start = _frame
			print("RUNSTART %d" % _frame))
	bus.connect("run_ended", func(c: StringName) -> void: print("EVENT run_ended %s frame %d" % [c, _frame]))
	process_frame.connect(_tick)


func _tick() -> void:
	_frame += 1
	if _frame == KILL_FRAME:
		root.get_node("SignalBus").emit_signal("run_end_requested", &"test")
	if _run_start < 0:
		return
	var local: int = _frame - _run_start
	if local == WALK_START:
		_held = KEY_D
		_send(_held, true)
	elif local == WALK_STOP:
		_send(_held, false)
	elif local == ERODE_AT - 1:
		var reveal: Node = _main.get_node("MapReveal")
		var cfg: RevealConfig = (reveal.get("config") as RevealConfig).duplicate()
		cfg.reveal_radius = WIDE_RADIUS
		reveal.set("config", cfg)
	elif local == ERODE_AT:
		_player.velocity = Vector3.ZERO
		_player.global_position = _loader.cell_to_world(Vector2i(27, 4))
	elif local == ERODE_AT + 130:
		Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
		quit()


func _send(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)
