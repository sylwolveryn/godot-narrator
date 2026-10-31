extends SceneTree
## Debug autopilot for the reveal and memory look (task-032, NOT part of the normal boot path). Run 1: opening,
## walking west (cells materialise). Run 2: remembered cells of run 1 in the memory style, then walking west
## again so they are re-seen (memory -> live). Uses a temporary save file (never the real progress).
##   tools/capture_at_size.sh 1920x1080 <dir> 420 tools/capture_reveal_memory.gd
## Prints "CAPTURE <label> frame <n>" lines; all frames are recorded, so strips can be cut at will.

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "capture_reveal_memory"

var _frame: int = 0
var _main: Node
var _runs: Node
var _held: Key = KEY_NONE

## Frame -> action. "press:<key>", "release", "end_run", "mark:<label>", "quit".
var _schedule: Dictionary = {
	110: "mark:r1_opening",
	112: "press:A",
	113: "mark:r1_walk_start",
	175: "release",
	200: "mark:r1_after",
	201: "press:W",
	215: "release",
	236: "mark:r1_end",
	241: "end_run",
	300: "mark:r2_opening",
	301: "press:A",
	302: "mark:r2_walk_start",
	360: "release",
	390: "mark:r2_after",
	391: "quit",
}


func _init() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	Support.isolate_save(_main, SAVE_TAG)
	var intro := IntroConfig.new()
	intro.black_hold = 0.3
	intro.wave_fade_in = 0.3
	intro.wave_hold = 0.5
	intro.reveal_duration = 0.8
	_main.get_node("IntroSequence").set("config", intro)
	_runs = _main.get_node("RunManager")
	var run_cfg: RunConfig = _runs.get("config").duplicate()
	run_cfg.restart_delay = 0.4
	_runs.set("config", run_cfg)
	root.add_child(_main)
	process_frame.connect(_tick)


func _tick() -> void:
	_frame += 1
	if not _schedule.has(_frame):
		return
	var action: String = _schedule[_frame]
	if action.begins_with("press:"):
		_held = OS.find_keycode_from_string(action.get_slice(":", 1))
		_send(_held, true)
	elif action == "release":
		_send(_held, false)
	elif action == "end_run":
		_runs.call("end_run", &"capture")
	elif action.begins_with("mark:"):
		print("CAPTURE %s frame %d" % [action.get_slice(":", 1), _frame])
	elif action == "quit":
		Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
		quit()


func _send(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)
