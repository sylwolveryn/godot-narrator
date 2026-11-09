extends SceneTree
## Debug autopilot for the death marks visual check (task-093; NOT part of the normal boot path). On M1: dies on the
## spikes twice (two purple / red stains; the second death passes 10 stained tiles and throws the ⚛ item), walks onto
## the item (the energy shield turns around the player), then stands in the corruption unharmed.
## Uses a temporary save file (never the real progress). Movie Maker capture:
##   tools/capture_at_size.sh 1366x768 <dir> 345 tools/capture_death_marks.gd
## Prints "CAPTURE <label> frame <n>" lines so the matching PNGs can be picked.

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "capture_death_marks"
const WIDE_RADIUS := 8.0

var _frame: int = 0
var _main: Node
var _player: CharacterBody3D
var _loader: MapLoader

## Frame -> action. "tp:<x>,<y>", "tp_item", "wide", "mark:<label>", "quit".
## Cells (M1): spikes (23,3) (24,3), corruption (26..28, 3..4).
var _schedule: Dictionary = {
	110: "wide",
	111: "tp:21,4",
	140: "tp:24,3",
	200: "mark:first_stain",
	201: "tp:23,3",
	262: "mark:second_stain_item",
	263: "tp_item",
	275: "mark:shield_a",
	290: "mark:shield_b",
	291: "tp:27,4",
	320: "mark:shield_in_corruption",
	340: "quit",
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
	bus.connect("invulnerability_item_dropped", func(c: Vector2i, _w: Vector3) -> void: print("EVENT item %s frame %d" % [c, _frame]))
	process_frame.connect(_tick)


func _tick() -> void:
	_frame += 1
	if not _schedule.has(_frame):
		return
	var action: String = _schedule[_frame]
	if action.begins_with("tp:"):
		var xy: PackedStringArray = action.get_slice(":", 1).split(",")
		_tp(Vector2i(int(xy[0]), int(xy[1])))
	elif action == "tp_item":
		var items: Dictionary = _main.get_node("DeathMarks").call("items")
		if not items.is_empty():
			_tp(items.keys()[0])
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


func _tp(cell: Vector2i) -> void:
	_player.velocity = Vector3.ZERO
	_player.global_position = _loader.cell_to_world(cell)
