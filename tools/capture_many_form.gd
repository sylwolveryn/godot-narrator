extends SceneTree
## Dev capture autopilot for the many form shapes (task-099; NOT part of the normal boot path). Seeds a temporary save
## with the many form unlocked (identity from the "glyph=" user arg, default "Q"), lets the grow moment play, then
## forces each shape of the morph in turn - human, lion head, angelic, hand - plus a half-way morph, and prints
## "SHOT <name> <frame>" for each. The real save is never touched. Movie Maker capture:
##   tools/capture_at_size.sh 1366x768 <dir> 330 tools/capture_many_form.gd -- glyph=Q

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "capture_many_form"
## Frames (30 fps) from the start: the grown body has settled by SETTLED; each pose then holds for POSE_FRAMES.
const SETTLED := 120
const POSE_FRAMES := 40
## [name, from shape, to shape, morph progress (0..1)]; shape 0 = the human base.
const POSES: Array = [
	["human", 0, 0, 0.0],
	["lion_head", 1, 1, 0.0],
	["human_to_angelic_half", 0, 2, 0.5],
	["angelic", 2, 2, 0.0],
	["hand", 3, 3, 0.0],
]

var _frame: int = 0
var _main: Node
var _glyph: String = "Q"


func _init() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("glyph="):
			_glyph = a.get_slice("=", 1)
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	var path: String = Support.isolate_save(_main, SAVE_TAG)
	var seeded := PersistentProgress.new()
	seeded.identity_glyph = _glyph
	seeded.run_count = 3
	seeded.death_count = 3
	seeded.entity_unlocked = true
	seeded.menu_unlocked = true
	ResourceSaver.save(seeded, path)
	var intro := IntroConfig.new()
	intro.black_hold = 0.1
	intro.wave_fade_in = 0.1
	intro.wave_hold = 0.1
	intro.reveal_duration = 0.2
	_main.get_node("IntroSequence").set("config", intro)
	root.add_child(_main)
	process_frame.connect(_tick)


func _tick() -> void:
	_frame += 1
	var local: int = _frame - SETTLED
	if local < 0 or local % POSE_FRAMES != 0:
		return
	var i: int = local / POSE_FRAMES
	if i >= POSES.size():
		Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
		quit()
		return
	var body: Node = _main.get_node("PlayerGlyphView").call("entity_body")
	var m: EntityMorph = body.call("morph")
	var pose: Array = POSES[i]
	m.from_index = pose[1]
	m.to_index = pose[2]
	m.phase = EntityMorph.Phase.MORPH if pose[1] != pose[2] else EntityMorph.Phase.HOLD
	m.length = 1000.0
	m.time = m.length * float(pose[3])
	body.call("_write_morph")
	print("SHOT %s %d" % [pose[0], _frame + POSE_FRAMES / 2])
