extends SceneTree
## Debug autopilot for the death splat polish visual check (task-104; NOT part of the normal boot path). On M1: dies on
## the spike (11,12) (a crimson splat of radius 2-4), steps into the splat and walks east along row 11 (the trail turns
## crimson and marks the floor), then a black hole forms at (25,11) and the player walks through it (dark purple trail
## and marks). Uses a temporary save file (never the real progress). Movie Maker capture:
##   tools/capture_at_size.sh 1366x768 <dir> 330 tools/capture_death_splat.gd
## Prints "CAPTURE <label> frame <n>" lines so the matching PNGs can be picked.

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "capture_death_splat"
const WIDE_RADIUS := 9.0
const STEP_FRAMES := 4

var _frame: int = 0
var _main: Node
var _player: CharacterBody3D
var _loader: MapLoader
var _schedule: Dictionary = {}


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
	_main.get_node("Invulnerability").set("respawn_seconds", 0.0)
	_player = _main.get_node("Player")
	_loader = _main.get_node("World/MapLoader")
	root.add_child(_main)
	var bus: Node = root.get_node("SignalBus")
	bus.connect("run_started", func(i: int) -> void: print("EVENT run_started %d frame %d" % [i, _frame]))
	bus.connect("trail_tint_changed", func(k: StringName) -> void: print("EVENT tint '%s' frame %d" % [k, _frame]))
	_schedule[110] = "wide"
	_schedule[111] = "tp:11,12"
	_schedule[170] = "mark:splat"
	_schedule[171] = "tp:9,11"
	var f: int = 180
	for x in range(10, 22):
		_schedule[f] = "tp:%d,11" % x
		f += STEP_FRAMES
	_schedule[f] = "mark:blood_trail"
	_schedule[f + 1] = "hole:25,11"
	f += 4
	for x in range(23, 33):
		_schedule[f] = "tp:%d,11" % x
		f += STEP_FRAMES
	_schedule[f] = "mark:void_trail"
	_schedule[f + 1] = "tp:17,9"
	_schedule[f + 6] = "mark:marks_overview"
	_schedule[f + 10] = "quit"
	process_frame.connect(_tick)


func _tick() -> void:
	_frame += 1
	if not _schedule.has(_frame):
		return
	var action: String = _schedule[_frame]
	if action.begins_with("tp:"):
		_tp(_cell(action))
	elif action.begins_with("hole:"):
		_main.get_node("EnemyRemains").call("form_black_hole", _cell(action))
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


func _cell(action: String) -> Vector2i:
	var xy: PackedStringArray = action.get_slice(":", 1).split(",")
	return Vector2i(int(xy[0]), int(xy[1]))


func _tp(cell: Vector2i) -> void:
	_player.velocity = Vector3.ZERO
	_player.global_position = _loader.cell_to_world(cell)
