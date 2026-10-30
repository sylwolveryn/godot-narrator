extends SceneTree
## Debug autopilot for the hazard visual check (NOT part of the normal boot path). Teleports the
## player into a corrupting patch (erosion scrambles the glyph), walks it out, then onto spikes
## (death presentation) and lets the automatic restart play. Uses a temporary save file.
##   godot --path . --resolution 960x540 --fixed-fps 30 --quit-after 300 --write-movie <dir>/f.png -s tools/capture_hazards.gd
## Prints "CAPTURE <label> frame <n>" lines so the matching PNGs can be picked.

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "capture_hazards"

var _frame: int = 0
var _main: Node
var _player: CharacterBody3D
var _loader: MapLoader
var _held: Key = KEY_NONE

## Frame -> action. "press:<key>", "release", "tp:<x>,<y>", "mark:<label>", "quit".
var _schedule: Dictionary = {
	110: "mark:opening",
	118: "press:D",
	119: "release",
	120: "tp:27,4",
	135: "mark:erosion_early",
	150: "mark:erosion_mid",
	168: "mark:erosion_late",
	170: "press:A",
	190: "release",
	195: "mark:recovering",
	196: "tp:21,3",
	197: "press:D",
	240: "release",
	280: "mark:after_restart",
	290: "quit",
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
	_player = _main.get_node("Player")
	_loader = _main.get_node("World/MapLoader")
	root.add_child(_main)
	var bus: Node = root.get_node("SignalBus")
	bus.connect("run_started", func(i: int) -> void: print("EVENT run_started %d frame %d" % [i, _frame]))
	bus.connect("run_ended", func(c: StringName) -> void: print("EVENT run_ended %s frame %d" % [c, _frame]))
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
	elif action.begins_with("tp:"):
		var xy: PackedStringArray = action.get_slice(":", 1).split(",")
		_player.velocity = Vector3.ZERO
		_player.global_position = _loader.cell_to_world(Vector2i(int(xy[0]), int(xy[1])))
	elif action.begins_with("mark:"):
		print("CAPTURE %s frame %d cell %s" % [action.get_slice(":", 1), _frame, _loader.world_to_cell(_player.global_position)])
	elif action == "quit":
		Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
		quit()


func _send(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)
