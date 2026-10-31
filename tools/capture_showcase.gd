extends SceneTree
## Debug autopilot for the look review (task-026, NOT part of the normal boot path). Like
## a plain idle capture but with a wide reveal radius (a "full view" of structures, light, memory and
## hazards, much wider than the in-game 2 cells) and a second stop so the first area is remembered.
## Uses a temporary save file. Capture with Movie Maker, e.g.
##   tools/capture_at_size.sh 1920x1080 <dir> 420 tools/capture_showcase.gd
## Prints "CAPTURE <label> frame <n>" lines.

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "capture_showcase"
const SHOWCASE_RADIUS := 8.0

var _frame: int = 0
var _main: Node
var _player: CharacterBody3D
var _loader: MapLoader

## Frame -> action. "tp:<x>,<y>", "mark:<label>", "quit".
var _schedule: Dictionary = {
	120: "tp:25,3",
	121: "mark:reveal_start",
	230: "mark:hazards_view",
	240: "tp:14,8",
	360: "mark:memory_view",
	361: "quit",
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
	var reveal_cfg: RevealConfig = (_main.get_node("MapReveal").get("config") as RevealConfig).duplicate()
	reveal_cfg.reveal_radius = SHOWCASE_RADIUS
	_main.get_node("MapReveal").set("config", reveal_cfg)
	_player = _main.get_node("Player")
	_loader = _main.get_node("World/MapLoader")
	root.add_child(_main)
	process_frame.connect(_tick)


func _tick() -> void:
	_frame += 1
	if not _schedule.has(_frame):
		return
	var action: String = _schedule[_frame]
	if action.begins_with("tp:"):
		var xy: PackedStringArray = action.get_slice(":", 1).split(",")
		_player.velocity = Vector3.ZERO
		_player.global_position = _loader.cell_to_world(Vector2i(int(xy[0]), int(xy[1])))
	elif action.begins_with("mark:"):
		print("CAPTURE %s frame %d" % [action.get_slice(":", 1), _frame])
	elif action == "quit":
		Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
		quit()
