extends SceneTree
## Debug autopilot for the glyph-world look review (task-031/036, NOT part of the normal boot path). Opening view,
## wall cut-away on and off at the same spot (a wall between camera and player), then a wide reveal radius and
## a tour over the whole M1 map. Uses a temporary save file (never the real progress). Movie Maker capture:
##   tools/capture_at_size.sh 1920x1080 <dir> 560 tools/capture_glyph_world.gd
## Prints "CAPTURE <label> frame <n>" lines.

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "capture_glyph_world"
const WIDE_RADIUS := 8.0

var _frame: int = 0
var _main: Node
var _player: CharacterBody3D
var _loader: MapLoader
var _view: Node

## Frame -> action. "tp:<x>,<y>", "cut:on|off", "wide", "mark:<label>", "quit".
var _schedule: Dictionary = {
	110: "mark:opening",
	205: "mark:spawn",
	212: "tp:16,12",
	250: "mark:cutaway_on",
	251: "cut:off",
	260: "mark:cutaway_off",
	261: "cut:on",
	262: "wide",
	263: "tp:25,3",
	305: "mark:north_room",
	306: "tp:5,17",
	350: "mark:southwest_room",
	351: "tp:20,19",
	395: "mark:south_spikes",
	396: "tp:33,8",
	440: "mark:east_room",
	441: "tp:20,8",
	485: "mark:centre",
	486: "tp:4,3",
	530: "mark:northwest_room",
	531: "tp:6,5",
	575: "mark:wall_corner",
	576: "tp:14,14",
	620: "mark:wall_between",
	621: "quit",
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
	_view = _main.get_node("GlyphWorldView")
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
	elif action.begins_with("cut:"):
		var cfg: GlyphWorldConfig = (_view.get("config") as GlyphWorldConfig).duplicate()
		cfg.cutaway_radius = 1.1 if action.ends_with("on") else 0.0
		cfg.cutaway_soft = 0.6 if action.ends_with("on") else 0.0001
		_view.set("config", cfg)
		_view.call("apply_static")
	elif action == "wide":
		var reveal: Node = _main.get_node("MapReveal")
		var cfg: RevealConfig = (reveal.get("config") as RevealConfig).duplicate()
		cfg.reveal_radius = WIDE_RADIUS
		reveal.set("config", cfg)
	elif action.begins_with("mark:"):
		print("CAPTURE %s frame %d" % [action.get_slice(":", 1), _frame])
	elif action == "quit":
		Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
		quit()
