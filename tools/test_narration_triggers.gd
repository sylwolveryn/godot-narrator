extends SceneTree
## Headless test of the new narration triggers (task-089, task-092):
##  - every new event has at least one beat and an EN_GB (or language) text file;
##  - FountainWhisper: English silent, DREAM gets the secret, other languages the whisper; once per fountain per run,
##    only within reach, again after a new run.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_narration_triggers.gd

const Support := preload("res://tools/test_support.gd")
const MAP := "res://data/maps/m2_arena.txt"
const PHASE_PLAYING := 1
const NEW_EVENTS: Array[StringName] = [&"FOUNTAIN_WHISPER", &"FOUNTAIN_SECRET", &"TELEPORT_DEPARTED", &"TELEPORT_ARRIVED",
	&"ENEMY_DESTROYED", &"CANNON_FIRED", &"MENU_ITEM_NEW", &"RESEARCH_DONE", &"CRAFT_LEARNED", &"CRAFTED",
	&"CRAFT_REFUSED", &"FORM_BLOCKED", &"BRAIN_UNLOCKED", &"TRANSFORMED_TO_BRAIN", &"BRAIN_LANGUAGE_SHIFT"]

var _failures: PackedStringArray = []
var _events: Array[StringName] = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	var narrator_cfg: NarratorConfig = load("res://resources/narration/narrator_config.tres")
	for e in NEW_EVENTS:
		var has_beat: bool = false
		for b: NarrationBeat in narrator_cfg.beats:
			if b.event == e:
				has_beat = true
		_check(has_beat, "%s has a beat" % e)
		var lang: String = "DREAM" if e == &"FOUNTAIN_SECRET" else ("HU_HU" if e == &"FOUNTAIN_WHISPER" else "EN_GB")
		_check(FileAccess.file_exists("res://narration/event/%s_%s.json" % [e, lang]), "%s has a %s text file" % [e, lang])

	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var save_path: String = Support.isolate_save(main, "narration_triggers")
	var loader = main.get_node("World/MapLoader")
	loader.map_path = MAP
	loader.use_cmdline_map = false
	root.add_child(main)
	root.get_node("SignalBus").connect(&"narration_event", func(e: StringName) -> void: _events.append(e))
	var runs = main.get_node("RunManager")
	var guard: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 5.0:
		await create_timer(0.1).timeout
		guard += 0.1
	var whisper = main.get_node("FountainWhisper")
	_check(whisper.event_for(&"EN_GB") == &"", "English hears nothing")
	_check(whisper.event_for(&"DREAM") == &"FOUNTAIN_SECRET", "DREAM reads the secret")
	_check(whisper.event_for(&"HU_HU") == &"FOUNTAIN_WHISPER", "other languages get the whisper")

	var fountain: LargeObjectPlacement = null
	for p: LargeObjectPlacement in loader.data.large_objects:
		if p.type == &"gargoyle":
			fountain = p
	_check(fountain != null, "m2 has a fountain")
	if fountain != null:
		var save = main.get_node("SaveService")
		var lang = main.get_node("LanguageProgress")
		save.progress.unlocked_languages = PackedStringArray(["EN_GB", "HU_HU", "DREAM"])
		save.progress.language_understanding = {"EN_GB": 10.0, "HU_HU": 10.0, "DREAM": 10.0}
		lang.select(&"EN_GB")
		var near: Vector2i = fountain.rect.position + Vector2i(-1, 0)
		var far: Vector2i = fountain.rect.position + Vector2i(-whisper.reach_cells - 3, 0)
		_check(whisper.check(near) == &"", "English near the fountain: nothing")
		lang.select(&"HU_HU")
		_check(whisper.check(near) == &"", "the fountain was already met this run")
		root.get_node("SignalBus").emit_signal(&"run_started", 9)
		_check(whisper.check(far) == &"", "too far: nothing")
		_events.clear()
		_check(whisper.check(near) == &"FOUNTAIN_WHISPER", "HU near the fountain: the whisper")
		_check(_events.has(&"FOUNTAIN_WHISPER"), "the whisper is a narration event")
		root.get_node("SignalBus").emit_signal(&"run_started", 10)
		lang.select(&"DREAM")
		_check(whisper.check(near) == &"FOUNTAIN_SECRET", "DREAM near the fountain: the secret")

	# --- Repeat ladder (task-087). ---
	var n = main.get_node("Narrator")
	var cfg: NarratorConfig = n.config
	var expect := {0: 1.0, 1: 0.8, 2: 0.6, 5: 0.2, 8: 0.03, 13: 0.02, 17: 0.02, 18: 0.01, 500: 0.01}
	for k: int in expect:
		_check(is_equal_approx(cfg.repeat_chance(k), expect[k]), "repeat chance after %d hearings = %s, got %s" % [k, expect[k], cfg.repeat_chance(k)])
	var line: NarrationBeat = n.pick_for_event(&"ENEMY_DESTROYED")
	_check(line != null and n.is_guaranteed(line), "an unheard story line is guaranteed")
	n._counts[line.id] = 5
	n.rng.seed = 7
	var passed: int = 0
	for i in 1000:
		n._candidates.clear()
		n._offer(&"ENEMY_DESTROYED")
		if not n._candidates.is_empty():
			passed += 1
	n._candidates.clear()
	_check(passed > 0 and passed < 1000, "a heard line plays only sometimes (%d of 1000)" % passed)
	# Every line of the event heard 5 times: the roll alone decides, at the 20 % rung.
	for b: NarrationBeat in cfg.beats:
		if b.event == &"ENEMY_DESTROYED":
			n._counts[b.id] = 5
	passed = 0
	for i in 1000:
		n._candidates.clear()
		n._offer(&"ENEMY_DESTROYED")
		if not n._candidates.is_empty():
			passed += 1
	n._candidates.clear()
	_check(passed > 150 and passed < 250, "after 5 hearings about 20 %% play again (%d of 1000)" % passed)
	var lang = main.get_node("LanguageProgress")
	var sel: StringName = lang.selected_language()
	var gains: Dictionary = {}
	for i in 30:
		var before: float = lang.percent(sel)
		root.get_node("SignalBus").emit_signal(&"beat_repeated", "x")
		gains[int(round(lang.percent(sel) - before))] = true
	_check(not gains.has(0) or lang.percent(sel) >= lang.cap(sel), "a repeat always teaches something below the cap")
	for g: int in gains:
		_check(g >= 0 and g <= 3, "a repeat teaches 1 to 3 %% (got %d)" % g)

	main.queue_free()
	await process_frame
	Support.remove_file(save_path)
	if _failures.is_empty():
		print("PASS test_narration_triggers")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_narration_triggers")
		quit(1)
