extends SceneTree
## Dev capture autopilot for the gargoyle fountain look (task-101; NOT part of the normal boot path). Loads the arena,
## stands the player south of the 3x2 fountain, reveals the area, zooms in and orbits the camera in 45 degree steps,
## saving one PNG per yaw (the viewport image, no Movie Maker) into the "out=" directory (default user://gargoyle_shots).
## Temporary save; the real progress is never touched. Windowed run (it renders):
##   godot --path . --max-fps 30 --windowed --resolution 1280x720 -s tools/capture_gargoyle.gd -- --map=m2_arena out=<dir>
## Optional user args: "cell=x,y" (player cell), "zoom=<steps>" (negative zooms in), "yaws=<count>".

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "capture_gargoyle"
const WIDE_RADIUS := 9.0
const SETTLED := 90
const POSE_FRAMES := 30
const YAW_STEP := 45.0

var _frame: int = 0
var _main: Node
var _player: CharacterBody3D
var _loader: Node3D
var _rig: Node3D
var _out: String = "user://gargoyle_shots"
var _cell: Vector2i = Vector2i(22, 18)
var _zoom: float = -4.0
var _yaws: int = 8
var _shot: int = 0
## Footprint of the fountain to crop around ("focus=x,y,w,h"), and the crop size in image pixels ("crop=w,h", 0 = off).
var _focus: Rect2i = Rect2i(21, 15, 3, 2)
var _crop: Vector2i = Vector2i(1000, 900)
const FOCUS_LIFT := 1.4


func _init() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.get_slice("=", 1)
		elif a.begins_with("cell="):
			var xy: PackedStringArray = a.get_slice("=", 1).split(",")
			_cell = Vector2i(int(xy[0]), int(xy[1]))
		elif a.begins_with("zoom="):
			_zoom = float(a.get_slice("=", 1))
		elif a.begins_with("yaws="):
			_yaws = int(a.get_slice("=", 1))
		elif a.begins_with("focus="):
			var f: PackedStringArray = a.get_slice("=", 1).split(",")
			_focus = Rect2i(int(f[0]), int(f[1]), int(f[2]), int(f[3]))
		elif a.begins_with("crop="):
			var c: PackedStringArray = a.get_slice("=", 1).split(",")
			_crop = Vector2i(int(c[0]), int(c[1]))
	DirAccess.make_dir_recursive_absolute(_out)
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	Support.isolate_save(_main, SAVE_TAG)
	var intro := IntroConfig.new()
	intro.black_hold = 0.1
	intro.wave_fade_in = 0.1
	intro.wave_hold = 0.1
	intro.reveal_duration = 0.2
	_main.get_node("IntroSequence").set("config", intro)
	_player = _main.get_node("Player")
	_loader = _main.get_node("World/MapLoader")
	_rig = _main.get_node("CameraRig")
	root.add_child(_main)
	process_frame.connect(_tick)


func _tick() -> void:
	_frame += 1
	if _frame == SETTLED - 40:
		var reveal: Node = _main.get_node("MapReveal")
		var cfg: RevealConfig = (reveal.get("config") as RevealConfig).duplicate()
		cfg.reveal_radius = WIDE_RADIUS
		reveal.set("config", cfg)
		_player.velocity = Vector3.ZERO
		_player.global_position = _loader.call("cell_to_world", _cell)
		_rig.call("zoom_by", _zoom)
	var local: int = _frame - SETTLED
	if local < 0 or local % POSE_FRAMES != 0:
		return
	if _shot > 0:
		var path: String = "%s/yaw_%03d.png" % [_out, int(round((_shot - 1) * YAW_STEP))]
		var img: Image = root.get_viewport().get_texture().get_image()
		if _crop.x > 0:
			# Crop around the fountain (its centre a little above the floor) so the review sees the detail.
			var cam: Camera3D = root.get_viewport().get_camera_3d()
			var a: Vector3 = _loader.call("cell_to_world", _focus.position)
			var b: Vector3 = _loader.call("cell_to_world", _focus.end - Vector2i.ONE)
			var at: Vector2 = cam.unproject_position((a + b) * 0.5 + Vector3.UP * FOCUS_LIFT)
			var scale: float = float(img.get_width()) / root.get_viewport().get_visible_rect().size.x
			var r := Rect2i(Vector2i(at * scale) - _crop / 2, _crop).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
			img = img.get_region(r)
		img.save_png(path)
		print("SHOT %s" % ProjectSettings.globalize_path(path))
	if _shot >= _yaws:
		Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
		quit()
		return
	if _shot > 0:
		_rig.call("rotate_by", YAW_STEP)
	_shot += 1
