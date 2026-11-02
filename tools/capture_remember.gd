extends SceneTree
## Dev capture autopilot for the ledger menu item "remember" (task-043; NOT part of the normal boot path). Seeds a
## temporary save (menu unlocked, no entity), starts a run and then: hears a claim, strikes one nature, strikes and
## recants another (through the real OriginLedger), opens the menu with Tab, confirms "remember" (the ledger row of
## sigils forms from the surroundings), holds it, goes back with confirm and closes with Tab. The real save is never
## touched. Movie Maker capture:
##   tools/capture_at_size.sh 1366x768 <dir> 380 tools/capture_remember.gd
## Prints "RUNSTART <frame>"; the offsets below are frames (30 fps) from the start of the run.

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "capture_remember"
const SEED_AT := 10
const OPEN_AT := 40
const REMEMBER_AT := 100
const BACK_AT := 250
const CLOSE_AT := 290
const END_AT := 340

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
	seeded.run_count = 4
	seeded.death_count = 1
	seeded.menu_unlocked = true
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
	bus.connect("menu_ledger_shown", func(e: Array) -> void: print("EVENT ledger %s frame %d" % [e, _frame]))
	bus.connect("menu_closed", func() -> void: print("EVENT menu_closed frame %d" % _frame))
	process_frame.connect(_tick)


func _tick() -> void:
	_frame += 1
	if _run_start < 0:
		return
	var local: int = _frame - _run_start
	match local:
		SEED_AT:
			var ledger: Node = _main.get_node("OriginLedger")
			root.get_node("SignalBus").emit_signal("origin_claim_heard", &"ai")
			ledger.call("strike", &"ai", 4)
			ledger.call("strike", &"demonic", 4)
			ledger.call("recant", &"demonic")
		OPEN_AT, CLOSE_AT:
			_tap(KEY_TAB)
		REMEMBER_AT, BACK_AT:
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
