extends SceneTree
## Dev capture autopilot for the glyph storm (task-030; NOT part of the normal boot path). Seeds a temporary save (menu era:
## menu + entity unlocked, the whole map remembered, the ai trial armed), starts a run, waits, then forces a strike of "ai"
## through the real OriginLedger so the storm and the BROKEN line play. The real save is never touched. Optional user args:
## "x,y" map cell to stand on; "nature=<id>" nature to strike. Movie Maker capture:
##   tools/capture_at_size.sh 1366x768 <dir> 200 tools/capture_storm.gd
## Prints "RUNSTART <frame>" and "STRIKE <frame>"; the storm lasts StormConfig.duration seconds (30 fps).

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "capture_storm"
const MAP_ID := &"m1_awakening"
const STRIKE_AT := 40
const END_AT := 170

var _frame: int = 0
var _run_start: int = -1
var _main: Node
var _nature: StringName = &"ai"
var _cell := Vector2i(-1, -1)


func _init() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("nature="):
			_nature = StringName(arg.substr(7))
		elif "," in arg:
			var parts: PackedStringArray = arg.split(",")
			_cell = Vector2i(int(parts[0]), int(parts[1]))
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	var path: String = Support.isolate_save(_main, SAVE_TAG)
	var seeded := PersistentProgress.new()
	seeded.identity_glyph = "Q"
	seeded.run_count = 6
	seeded.death_count = 5
	seeded.menu_unlocked = true
	seeded.entity_unlocked = true
	seeded.entity_grow_played = true
	seeded.entity_form = String(EntityForm.SINGLE)
	seeded.armed_trials = PackedStringArray([String(_nature)])
	var cells := PackedVector2Array()
	var map: MapData = _main.get_node("World/MapLoader").call("parse_text", FileAccess.get_file_as_string("res://data/maps/m1_awakening.txt"))
	for y in map.height:
		for x in map.width:
			if map.type_at(Vector2i(x, y)) != MapLegend.VOID:
				cells.append(Vector2(x, y))
	seeded.revealed_cells[MAP_ID] = cells
	ResourceSaver.save(seeded, path)
	var intro := IntroConfig.new()
	intro.black_hold = 0.1
	intro.wave_fade_in = 0.1
	intro.wave_hold = 0.1
	intro.reveal_duration = 0.2
	_main.get_node("IntroSequence").set("config", intro)
	root.add_child(_main)
	var bus: Node = root.get_node("SignalBus")
	bus.connect("run_started", func(i: int) -> void:
		if _run_start < 0:
			_run_start = _frame
			print("RUNSTART %d (run %d)" % [_frame, i]))
	process_frame.connect(_tick)


func _tick() -> void:
	_frame += 1
	if _run_start < 0:
		return
	var local: int = _frame - _run_start
	if local == 3 and _cell.x >= 0:
		var player: CharacterBody3D = _main.get_node("Player")
		player.global_position = _main.get_node("World/MapLoader").call("cell_to_world", _cell)
	if local == STRIKE_AT:
		print("STRIKE %d" % _frame)
		_main.get_node("OriginLedger").call("strike", _nature, 6)
	if local == END_AT:
		Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
		quit()
