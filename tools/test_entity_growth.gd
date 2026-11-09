extends SceneTree
## Headless test of the multi-glyph entity (task-017): the unlock at the configured death count (not before), its
## persistence through save/load, the grow moment on the first run after the unlock, the form API (single <-> grown),
## deterministic formations, and erosion / death of the grown entity on the real main scene.
## Usage: godot --headless --path . -s tools/test_entity_growth.gd

const Support := preload("res://tools/test_support.gd")
const PATH := "user://test_progress_entity_growth_data.tres"
const SAVE_TAG := "entity_growth_main"
const PHASE_PLAYING := 1
const STATE_GROWN := 2

var _failures: PackedStringArray = []
var _unlocked_signals: int = 0
var _grown_signals: int = 0
var _forms: Array = []


## Held so the scene shares this (cached) config with whole_body off (task-090).
var _growth_cfg: EntityGrowthConfig

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


# Scripts that use the SignalBus autoload are loaded at runtime (not preloaded as class names).
func _service() -> Node:
	var cfg := SaveConfig.new()
	cfg.save_path = PATH
	var svc: Node = load("res://scripts/core/save_service.gd").new()
	svc.set("config", cfg)
	root.add_child(svc)
	return svc


func _progression(svc: Node, cfg: EntityGrowthConfig) -> Node:
	var prog: Node = load("res://scripts/core/entity_progression.gd").new()
	prog.set("config", cfg)
	prog.set("save_service", svc)
	root.add_child(prog)
	return prog


func _on_form(form: StringName, animate: bool) -> void:
	_forms.append([form, animate])


func _run() -> void:
	Support.remove_file(PATH)
	var bus: Node = root.get_node("SignalBus")
	bus.connect("entity_unlocked", func() -> void: _unlocked_signals += 1)
	bus.connect("entity_grown", func() -> void: _grown_signals += 1)
	bus.connect("entity_form_changed", _on_form)
	var cfg := load("res://resources/config/entity_growth_config.tres") as EntityGrowthConfig
	_check(cfg != null and cfg.growth_unlock_deaths == 3 and cfg.formations.size() > 0, "config resource should load with threshold 3")

	# --- unlock exactly at the threshold ---
	var svc: Node = _service()
	var prog: Node = _progression(svc, cfg)
	for i in cfg.growth_unlock_deaths - 1:
		bus.emit_signal("run_started", i)
		bus.emit_signal("run_ended", &"test")
		_check(not prog.call("is_unlocked"), "must not unlock before death %d" % cfg.growth_unlock_deaths)
	_check(_unlocked_signals == 0 and not prog.call("set_form", EntityForm.GROWN), "no signal and no form switch before the unlock")
	bus.emit_signal("run_started", 2)
	_check(_forms.is_empty(), "no form event before the unlock")
	bus.emit_signal("run_ended", &"test")
	_check(prog.call("is_unlocked") and _unlocked_signals == 1, "unlocks at the threshold, one signal")
	_check(prog.call("current_form") == EntityForm.SINGLE, "still single until the grow moment")

	# --- persists through save/load ---
	svc.free()
	prog.free()
	svc = _service()
	prog = _progression(svc, cfg)
	_check(prog.call("is_unlocked") and svc.get("progress").death_count == 3, "unlock survives a restart")
	_check(not svc.get("progress").entity_grow_played, "grow moment not played yet")

	# --- grow moment on the first run after the unlock, once ---
	bus.emit_signal("run_started", 3)
	_check(_grown_signals == 1, "entity_grown on the first run after the unlock")
	_check(not _forms.is_empty() and _forms[-1][0] == EntityForm.GROWN and _forms[-1][1] == true, "grown form announced with animation")
	_check(prog.call("current_form") == EntityForm.GROWN, "grown is the default active form")
	svc.free()
	prog.free()
	svc = _service()
	prog = _progression(svc, cfg)
	_check(svc.get("progress").entity_grow_played and prog.call("current_form") == EntityForm.GROWN, "grown form and played flag persist")
	bus.emit_signal("run_started", 4)
	_check(_grown_signals == 1 and _forms[-1][0] == EntityForm.GROWN and _forms[-1][1] == false, "later runs show the grown form without the moment")

	# --- form API ---
	_check(prog.call("set_form", EntityForm.SINGLE) and prog.call("current_form") == EntityForm.SINGLE, "switch to single")
	_check(_forms[-1][0] == EntityForm.SINGLE and _forms[-1][1] == true, "switch announced")
	_check(not prog.call("set_form", &"bogus"), "unknown form refused")
	svc.free()
	prog.free()
	svc = _service()
	_check(svc.get("progress").entity_form == "single", "chosen form persists")
	svc.free()

	# --- a tampered form name falls back to single ---
	var bad := PersistentProgress.new()
	bad.entity_unlocked = true
	bad.entity_form = "evil"
	bad.entity_grow_played = true
	ResourceSaver.save(bad, PATH)
	svc = _service()
	_check(svc.get("progress").entity_form == "single" and svc.get("progress").entity_unlocked, "invalid form sanitised")
	svc.free()
	Support.remove_file(PATH)

	# --- determinism of the silhouette ---
	var a: EntityLayout = cfg.formation_for("Q").resolve("Q", cfg.body_glyphs)
	var b: EntityLayout = cfg.formation_for("Q").resolve("Q", cfg.body_glyphs)
	_check(a.glyphs == b.glyphs and a.offsets == b.offsets, "same identity grows the same body")
	for f in cfg.formations:
		var n: int = f.resolve("@", cfg.body_glyphs).size()
		_check(n >= 15 and n <= 40, "formation %s has %d glyphs, want 15..40" % [f.id, n])

	await _main_scene(cfg)

	if _failures.is_empty():
		print("PASS test_entity_growth")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_entity_growth")
		quit(1)


func _main_scene(cfg: EntityGrowthConfig) -> void:
	# These checks predate task-090 and run on small maps: test them with the heart-sized collider.
	_growth_cfg = load("res://resources/config/entity_growth_config.tres")
	_growth_cfg.whole_body = false
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var path: String = Support.isolate_save(main, SAVE_TAG)
	var seed_progress := PersistentProgress.new()
	seed_progress.identity_glyph = "Q"
	seed_progress.run_count = cfg.growth_unlock_deaths - 1
	seed_progress.death_count = cfg.growth_unlock_deaths - 1
	ResourceSaver.save(seed_progress, path)
	var intro := IntroConfig.new()
	intro.black_hold = 0.05
	intro.wave_fade_in = 0.05
	intro.wave_hold = 0.05
	intro.reveal_duration = 0.05
	main.get_node("IntroSequence").set("config", intro)
	var run_cfg: RunConfig = (main.get_node("RunManager").get("config") as RunConfig).duplicate()
	run_cfg.restart_delay = 0.6
	main.get_node("RunManager").set("config", run_cfg)
	# Task-104 splats spray up to 49 tiles, so the first death could throw a ⚛ item (invulnerable: no erosion); keep 9 tiles.
	main.get_node("DeathMarks").set("radius_override", 1.5)
	root.add_child(main)
	var view: Node = main.get_node("PlayerGlyphView")
	var body: Node = view.call("entity_body")
	var runs: Node = main.get_node("RunManager")
	var prog: Node = main.get_node("EntityProgression")
	await _wait(0.5)
	_check(runs.get("phase") == PHASE_PLAYING and view.call("form") == EntityForm.SINGLE and not body.call("is_shown"), "locked: single glyph only")

	# third death unlocks; the next run grows the entity
	var bus: Node = root.get_node("SignalBus")
	bus.emit_signal("run_end_requested", &"test")
	await _wait(0.2)
	_check(prog.call("is_unlocked"), "third death unlocks in the real scene")
	var guard: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 3.0:
		await _wait(0.1)
		guard += 0.1
	await _wait(0.3)
	_check(view.call("form") == EntityForm.GROWN and body.call("is_growing") and body.call("glyph_count") >= 15, "grow moment plays at the start of the run")
	await _wait(body.call("grow_duration") + 0.5)
	_check(body.get("state") == STATE_GROWN and body.call("is_shown"), "grown entity settled after the moment")

	# form API: single and back
	view.call("set_form", EntityForm.SINGLE, false)
	_check(not body.call("is_shown") and view.call("form") == EntityForm.SINGLE, "set_form(single) hides the body")
	view.call("set_form", EntityForm.GROWN, false)
	_check(body.get("state") == STATE_GROWN, "set_form(grown) shows the body")
	view.call("set_form", EntityForm.SINGLE, true)
	await _wait(cfg.fold_duration + body.call("grow_duration") * 0.4 + 0.3)
	_check(not body.call("is_shown"), "fold finishes hidden")
	view.call("set_form", EntityForm.GROWN, true)
	_check(body.call("is_growing"), "set_form(grown, animate) replays the growth")
	await _wait(body.call("grow_duration") + 0.3)

	# erosion applies to the whole entity (the level is shared), death bursts it
	var player: CharacterBody3D = main.get_node("Player")
	var loader: MapLoader = main.get_node("World/MapLoader")
	var corrupt_def: HazardDefinition = loader.legend.hazards.get(MapLegend.CORRUPT)
	corrupt_def.erosion_rate = 1.0
	corrupt_def.erosion_threshold = 3.0
	var cell := Vector2i(-1, -1)
	for y in loader.data.height:
		for x in loader.data.width:
			if cell.x < 0 and loader.data.type_at(Vector2i(x, y)) == MapLegend.CORRUPT:
				cell = Vector2i(x, y)
	player.velocity = Vector3.ZERO
	player.global_position = loader.cell_to_world(cell)
	await _wait(2.0)
	_check(view.call("shown_level") > 0.3 and body.call("is_shown"), "grown entity erodes with the heart")
	await _wait(1.5)
	_check(body.call("is_burst") and not view.call("is_glyph_visible"), "death bursts the entity and the heart")
	guard = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 4.0:
		await _wait(0.1)
		guard += 0.1
	await _wait(0.2)
	_check(not body.call("is_burst") and body.get("state") == STATE_GROWN and view.call("is_glyph_visible"), "next run: entity whole again")

	main.queue_free()
	await process_frame
	Support.remove_file(path)
