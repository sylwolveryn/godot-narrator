extends SceneTree
## Debug autopilot for visual checks (NOT part of the normal boot path). Runs the main scene,
## feeds key events on a fixed frame schedule and quits. Meant for Movie Maker captures:
##   godot --path . --resolution 960x540 --fixed-fps 30 --write-movie <dir>/f.png -s tools/capture_reveal.gd
## Prints "CAPTURE <label> frame <n>" lines so the matching PNGs can be picked.

const FPS := 30
var _frame: int = 0
var _main: Node
var _runs: Node
var _held: Key = KEY_NONE

## Frame -> action. Keys: "press:<name>", "release", "end_run", "mark:<label>", "quit".
var _schedule: Dictionary = {
	110: "mark:opening",
	120: "press:A",
	185: "release",
	186: "press:W",
	215: "release",
	240: "mark:walked",
	241: "end_run",
	300: "mark:second_run",
	301: "press:D",
	330: "release",
	360: "mark:second_run_walking",
	361: "quit",
}


func _init() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	_main = (load("res://main.tscn") as PackedScene).instantiate()
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
		quit()


func _send(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)
