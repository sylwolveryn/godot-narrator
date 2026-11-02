extends SceneTree
## Dev capture autopilot for task-034 (narration + intro in the iso glyph world; NOT part of the normal boot path).
## Modes (user arg): intro | narr | death | entity | menu. Every mode runs on a temporary save (the real one is never
## touched) and prints "RUNSTART <frame>" plus beat events. Movie Maker capture:
##   tools/capture_at_size.sh 1366x768 <dir> 240 tools/capture_narration_view.gd intro
## intro  : real intro timings; the whole black -> wave -> world hand-off.
## narr   : short intro, then the first-run beats (wake_first assembles, holds, disperses).
## death  : a spikes death beat over the death burst (player teleported onto the spikes), run 1 save.
## entity : seeded save with the grown entity and the menu unlocked; a narration beat while grown.
## menu   : the same seed; opens the menu and a beat is forced on while it is open.

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "capture_narration_view"
const SPIKES_NEAR := Vector2i(13, 3)
const SPIKES_ON := Vector2i(15, 3)
const NARRATE_AT := 12
const MENU_OPEN_AT := 30
const MENU_BEAT_AT := 75
const DEATH_TP_NEAR := 60
const DEATH_TP_ON := 125
const END_AT := 330

var _frame: int = 0
var _run_start: int = -1
var _mode: String = "narr"
var _main: Node
var _player: CharacterBody3D
var _loader: MapLoader


func _init() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_mode = args[0]
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	var path: String = Support.isolate_save(_main, SAVE_TAG)
	if _mode == "entity" or _mode == "menu":
		var seeded := PersistentProgress.new()
		seeded.identity_glyph = "Q"
		seeded.run_count = 3
		seeded.death_count = 3
		seeded.entity_unlocked = true
		seeded.entity_grow_played = true
		seeded.menu_unlocked = true
		seeded.entity_form = String(EntityForm.GROWN)
		ResourceSaver.save(seeded, path)
	if _mode != "intro":
		var intro := IntroConfig.new()
		intro.black_hold = 0.1
		intro.wave_fade_in = 0.1
		intro.wave_hold = 0.1
		intro.reveal_duration = 0.2
		_main.get_node("IntroSequence").set("config", intro)
	_player = _main.get_node("Player")
	_loader = _main.get_node("World/MapLoader")
	root.add_child(_main)
	var bus: Node = root.get_node("SignalBus")
	bus.connect("run_started", func(i: int) -> void:
		if _run_start < 0:
			_run_start = _frame
			print("RUNSTART %d (run %d)" % [_frame, i]))
	bus.connect("run_ended", func(c: StringName) -> void: print("EVENT run_ended %s frame %d" % [c, _frame]))
	var narrator: Node = _main.get_node("Narrator")
	narrator.connect("beat_started", func(b: NarrationBeat) -> void: print("EVENT beat_started %s (%s) frame %d" % [b.id, b.mood, _frame]))
	narrator.connect("beat_dissolving", func(fast: bool) -> void: print("EVENT beat_dissolving fast=%s frame %d" % [fast, _frame]))
	process_frame.connect(_tick)


func _tick() -> void:
	_frame += 1
	if _run_start < 0:
		return
	var local: int = _frame - _run_start
	match _mode:
		"death":
			if local == DEATH_TP_NEAR:
				_teleport(SPIKES_NEAR)
			elif local == DEATH_TP_ON:
				_teleport(SPIKES_ON)
		"menu":
			if local == MENU_OPEN_AT:
				_tap(KEY_TAB)
			elif local == MENU_BEAT_AT:
				_main.get_node("Narrator").call("trigger_event", &"wall_revealed")
	if local == END_AT or (_mode == "intro" and local == 90):
		Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
		_main.queue_free()
		await process_frame
		Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
		quit()


func _teleport(cell: Vector2i) -> void:
	_player.velocity = Vector3.ZERO
	_player.global_position = _loader.cell_to_world(cell)


func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
