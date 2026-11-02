extends SceneTree
## Dev capture autopilot for small-object pushing (task-019; NOT part of the normal boot path). Seeds a temporary save past
## the growth threshold (grown form active), then records: a wide shot of the objects, the grown entity pushing an object
## west (before / during / after), and the single glyph walking into the same object (blocked). The real save is never
## touched. Movie Maker capture:
##   tools/capture_at_size.sh 1366x768 <dir> 330 tools/capture_pushing.gd
## Prints "RUNSTART <frame>"; capture frames are relative to it (see the offsets below).

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "capture_pushing"
const WIDE_RADIUS := 7.0
## Offsets from the start of the run (frames at 30 fps).
const WIDE_AT := 10
const GROWN_AT := 50
const PUSH_START := 80
const PUSH_STOP := 140
const SINGLE_AT := 160
const SINGLE_START := 185
const SINGLE_STOP := 235
const END_AT := 250
const WIDE_CELL := Vector2i(22, 9)
const START_CELL := Vector2i(7, 3)

var _frame: int = 0
var _run_start: int = -1
var _main: Node
var _player: CharacterBody3D
var _loader: MapLoader


func _init() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	var path: String = Support.isolate_save(_main, SAVE_TAG)
	var seeded := PersistentProgress.new()
	seeded.identity_glyph = "Q"
	seeded.run_count = 3
	seeded.death_count = 3
	seeded.entity_unlocked = true
	seeded.entity_grow_played = true
	seeded.entity_form = String(EntityForm.GROWN)
	ResourceSaver.save(seeded, path)
	var intro := IntroConfig.new()
	intro.black_hold = 0.1
	intro.wave_fade_in = 0.1
	intro.wave_hold = 0.1
	intro.reveal_duration = 0.2
	_main.get_node("IntroSequence").set("config", intro)
	_player = _main.get_node("Player")
	_loader = _main.get_node("World/MapLoader")
	root.add_child(_main)
	root.get_node("SignalBus").connect("run_started", func(_i: int) -> void:
		if _run_start < 0:
			_run_start = _frame
			print("RUNSTART %d" % _frame))
	root.get_node("SignalBus").connect("object_moved", func(id: int, f: Vector2i, t: Vector2i, form: StringName) -> void:
		print("EVENT object_moved %d %s -> %s %s frame %d" % [id, f, t, form, _frame]))
	process_frame.connect(_tick)


func _tick() -> void:
	_frame += 1
	if _run_start < 0:
		return
	var local: int = _frame - _run_start
	match local:
		1:
			var reveal: Node = _main.get_node("MapReveal")
			var cfg: RevealConfig = (reveal.get("config") as RevealConfig).duplicate()
			cfg.reveal_radius = WIDE_RADIUS
			reveal.set("config", cfg)
		WIDE_AT:
			_teleport(WIDE_CELL)
		GROWN_AT:
			_teleport(START_CELL)
		PUSH_START:
			_east(true)
		PUSH_STOP:
			_east(false)
		SINGLE_AT:
			_main.get_node("EntityProgression").call("set_form", EntityForm.SINGLE)
			_main.get_node("PushableObjects").call("reset")
			_teleport(START_CELL)
		SINGLE_START:
			_east(true)
		SINGLE_STOP:
			_east(false)
		END_AT:
			Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
			quit()


func _teleport(cell: Vector2i) -> void:
	_player.velocity = Vector3.ZERO
	_player.global_position = _loader.cell_to_world(cell)


## Screen left + up is world -x with the isometric camera (yaw 45): pushes away from the camera.
func _east(pressed: bool) -> void:
	for code in [KEY_A, KEY_W]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
