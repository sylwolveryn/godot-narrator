extends SceneTree
## Dev capture autopilot for the in-world menu (task-018; NOT part of the normal boot path). Seeds a temporary save past
## both thresholds (death_count 3, entity unlocked, single form), starts a run and then, through real key events:
## opens the menu (glyphs of the surroundings fly into the framed list), holds it, moves the selection, confirms the
## form switch (the menu returns to the surroundings while the entity grows), reopens it as the grown entity and
## closes it with the toggle. The real save is never touched. Movie Maker capture:
##   tools/capture_at_size.sh 1366x768 <dir> 520 tools/capture_menu.gd
## Prints "RUNSTART <frame>"; the offsets below are frames (30 fps) from the start of the run.

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "capture_menu"
const OPEN_AT := 40
const DOWN_AT := 125
const UP_AT := 140
const CONFIRM_AT := 160
const REOPEN_AT := 290
const CLOSE_AT := 350
const END_AT := 440

var _frame: int = 0
var _run_start: int = -1
var _main: Node


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
	seeded.menu_unlocked = true
	seeded.entity_form = String(EntityForm.SINGLE)
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
	bus.connect("menu_opened", func(l: PackedStringArray, _s: int) -> void: print("EVENT menu_opened %s frame %d" % [l, _frame]))
	bus.connect("menu_closed", func() -> void: print("EVENT menu_closed frame %d" % _frame))
	bus.connect("entity_form_changed", func(f: StringName, a: bool) -> void: print("EVENT form %s animate %s frame %d" % [f, a, _frame]))
	process_frame.connect(_tick)


func _tick() -> void:
	_frame += 1
	if _run_start < 0:
		return
	var local: int = _frame - _run_start
	match local:
		OPEN_AT, REOPEN_AT, CLOSE_AT:
			_tap(KEY_TAB)
		DOWN_AT:
			_tap(KEY_DOWN)
		UP_AT:
			_tap(KEY_UP)
		CONFIRM_AT:
			_tap(KEY_ENTER)
		END_AT:
			Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
			quit()


func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
