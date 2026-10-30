extends SceneTree
## Debug autopilot for the narrator visual/audio check (NOT part of the normal boot path).
## Run 1: wake_first morphs in; the player is teleported next to spikes (reveal beat), then onto
## them (death beat over the shatter); run 2 starts (start beat). Uses a temporary save file.
##   godot --path . --resolution 960x540 --fixed-fps 30 --quit-after 720 --write-movie <dir>/f.png -s tools/capture_narrator.gd -- ttl12
## User arg `ttl12` raises the queue TTL to 12 s so the run-2 start beat survives the death beat
## (with the spec default of 5 s it is dropped). Prints "EVENT ... frame <n>" lines.

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "capture_narrator"
const LONG_TTL := 12.0

var _frame: int = 0
var _main: Node
var _player: CharacterBody3D
var _loader: MapLoader
var _held: Key = KEY_NONE

## Frame -> action. "press:<key>", "release", "tp:<x>,<y>", "quit".
var _schedule: Dictionary = {
	280: "tp:13,3",
	345: "tp:15,3",
	715: "quit",
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
	if OS.get_cmdline_user_args().has("ttl12"):
		var narrator_cfg: NarratorConfig = (_main.get_node("Narrator").get("config") as NarratorConfig).duplicate()
		narrator_cfg.queue_ttl_seconds = LONG_TTL
		_main.get_node("Narrator").set("config", narrator_cfg)
		_main.get_node("NarrationOverlay").set("config", narrator_cfg)
		_main.get_node("NarrationSfx").set("config", narrator_cfg)
	_player = _main.get_node("Player")
	_loader = _main.get_node("World/MapLoader")
	root.add_child(_main)
	var bus: Node = root.get_node("SignalBus")
	bus.connect("run_started", func(i: int) -> void: print("EVENT run_started %d frame %d" % [i, _frame]))
	bus.connect("run_ended", func(c: StringName) -> void: print("EVENT run_ended %s frame %d" % [c, _frame]))
	bus.connect("narration_event", func(e: StringName) -> void: print("EVENT narration_event %s frame %d" % [e, _frame]))
	_main.get_node("Narrator").connect("beat_started", func(b: NarrationBeat) -> void: print("EVENT beat_started %s (%s) frame %d" % [b.id, b.mood, _frame]))
	_main.get_node("Narrator").connect("beat_dissolving", func(fast: bool) -> void: print("EVENT beat_dissolving fast=%s frame %d" % [fast, _frame]))
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
	elif action == "quit":
		Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
		_main.queue_free()
		await process_frame
		Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
		quit()


func _send(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)
