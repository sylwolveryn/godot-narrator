extends SceneTree
## Debug autopilot for the hazard visual check (NOT part of the normal boot path). Reveals a wide area
## (items, spikes and corruption glow), teleports the player into the corrupting patch (erosion distorts the
## glyph until it breaks), lets the automatic restart play, then drops it onto spikes (death fragments).
## Uses a temporary save file (never the real progress). Movie Maker capture:
##   tools/capture_at_size.sh 1366x768 <dir> 370 tools/capture_hazards.gd
## Prints "CAPTURE <label> frame <n>" lines so the matching PNGs can be picked.

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "capture_hazards"
const WIDE_RADIUS := 8.0

var _frame: int = 0
var _main: Node
var _player: CharacterBody3D
var _loader: MapLoader
var _held: Key = KEY_NONE

## Frame -> action. "press:<key>", "release", "tp:<x>,<y>", "wide", "mark:<label>", "quit".
## Cells (M1): spikes (23,3) (24,3), corruption (26..28, 3..4), item (27,2): all three glow within one view.
var _schedule: Dictionary = {
	110: "mark:opening",
	115: "wide",
	116: "tp:25,4",
	150: "mark:glow_all",
	151: "tp:27,4",
	166: "mark:erosion_a",
	186: "mark:erosion_b",
	201: "mark:erosion_c",
	216: "mark:erosion_d",
	226: "mark:erosion_e",
	230: "mark:death_flash",
	233: "mark:death_burst_a",
	240: "mark:death_burst_b",
	250: "mark:death_burst_c",
	262: "mark:death_faded",
	300: "mark:after_restart",
	301: "tp:24,3",
	306: "mark:spike_flash",
	309: "mark:spike_burst_a",
	318: "mark:spike_burst_b",
	360: "mark:memory_after_restart",
	365: "quit",
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
	elif action == "wide":
		var reveal: Node = _main.get_node("MapReveal")
		var cfg: RevealConfig = (reveal.get("config") as RevealConfig).duplicate()
		cfg.reveal_radius = WIDE_RADIUS
		reveal.set("config", cfg)
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
