extends SceneTree
## Headless test of task-077 in the main scene (m1, temp save, DB off):
##  - consuming (SignalBus.consumed) is counted per kind in the save;
##  - the Items menu entry appears with the first consumption, is announced as new (the player pulse runs) and stops
##    being new once the menu has shown it; its list shows "<label> <count>" and a back entry;
##  - an old save's already-known items do not count as new;
##  - many form cannon: 1..6 balls per shot, autofire twice as fast, MANY_FIRED_CANNON narration event;
##  - language top limit (player_language.max): a value over it comes down to it and gains stop there.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_items_menu.gd

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "items_menu"
const MAP := "res://data/maps/m1_awakening.txt"
const PHASE_PLAYING := 1
const CannonScript := "res://scripts/world/cannon.gd"

var _failures: PackedStringArray = []
var _events: Array[StringName] = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	await _check_scene()
	if _failures.is_empty():
		print("PASS test_items_menu")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_items_menu")
		quit(1)


func _fast_intro() -> IntroConfig:
	var cfg := IntroConfig.new()
	cfg.reveal_duration = 0.05
	return cfg


func _check_scene() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var save_path: String = Support.isolate_save(main, SAVE_TAG)
	# An old save: menu already unlocked, new-item tracking not started, nothing consumed.
	var seeded := PersistentProgress.new()
	seeded.death_count = 3
	seeded.run_count = 3
	seeded.menu_unlocked = true
	seeded.identity_glyph = "Q"
	ResourceSaver.save(seeded, save_path)
	main.get_node("IntroSequence").set("config", _fast_intro())
	var loader: MapLoader = main.get_node("World/MapLoader")
	loader.map_path = MAP
	loader.use_cmdline_map = false
	root.add_child(main)
	var bus: Node = root.get_node("SignalBus")
	bus.connect(&"narration_event", func(e: StringName) -> void: _events.append(e))
	var runs: Node = main.get_node("RunManager")
	var guard: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 5.0:
		await create_timer(0.1).timeout
		guard += 0.1
	await create_timer(0.2).timeout

	var save = main.get_node("SaveService")
	var menu = main.get_node("MenuController")
	var view = main.get_node("GlyphWorldView")

	# --- Old save: known items are not new, no Items entry yet. ---
	_check(save.progress.menu_seen_initialized, "tracking initialised on an unlocked save")
	_check(not menu.has_new_items(), "an old save's items are not new")
	_check(not view.is_pulsing(), "no pulse without new items")
	_check(not menu.current_labels().has("items"), "no Items entry before anything is consumed")

	# --- First consumption: counted, Items entry offered and announced. ---
	bus.emit_signal(&"consumed", Consumable.DIRT)
	await process_frame
	_check(save.consumed_count(Consumable.DIRT) == 1, "dirt counted (%d)" % save.consumed_count(Consumable.DIRT))
	_check(menu.current_labels().has("items"), "Items entry offered after the first consumption")
	_check(menu.has_new_items(), "Items entry is new")
	_check(view.is_pulsing(), "the player pulse runs while an item is new")
	await process_frame
	var geo: Vector4 = view.pulse_geo()
	_check(geo.w > 0.0, "a pulse ring is drawn at once")
	var tile: float = loader.world_config.cell_size
	_check(geo.z <= view.config.pulse_radius_tiles * tile + 0.0001, "the ring stays within the pulse radius")
	bus.emit_signal(&"consumed", Consumable.DIAMOND)
	bus.emit_signal(&"consumed", Consumable.DIAMOND)
	await process_frame

	# --- Opening the menu shows the entry: no longer new, pulse stops. ---
	_check(menu.open(), "menu opens")
	await process_frame
	_check(not menu.has_new_items(), "seen once the menu showed it")
	_check(not view.is_pulsing(), "pulse stops once seen")
	_check(save.progress.seen_menu_items.has("items"), "seen item saved")
	var index: int = menu.current_labels().find("items")
	menu.move_selection(index - menu.selected_index())
	menu.confirm()
	_check(menu.is_items_shown(), "Items list shown")
	_check(menu.items_labels() == PackedStringArray(["dirt 1", "diamonds 2", "back"]), "Items list text %s" % [menu.items_labels()])
	menu.move_selection(2)
	menu.confirm_items()
	_check(not menu.is_items_shown() and menu.is_open(), "back returns to the item list")
	menu.close()

	# --- Many form cannon. ---
	var cannons = main.get_node("CannonSystem")
	var c = load(CannonScript).new(99, LargeObjectPlacement.new(&"cannon", Rect2i(Vector2i(3, 3), Vector2i.ONE)), cannons.config, cannons.fire)
	bus.emit_signal(&"entity_form_changed", EntityForm.SINGLE, false)
	_check(cannons.balls_per_shot() == 1, "one ball per shot in the single form")
	bus.emit_signal(&"entity_form_changed", EntityForm.GROWN, false)
	_check(cannons.is_many(), "grown form is the many form")
	var seen: Dictionary = {}
	for i in 400:
		seen[cannons.balls_per_shot()] = true
	_check(seen.has(1) and seen.has(6) and not seen.has(0) and not seen.has(7), "1..6 balls per shot (%s)" % [seen.keys()])
	var before: int = cannons.fired
	cannons.fire(c)
	_check(cannons.fired > before and cannons.fired - before <= 6, "a many shot launches 1..6 balls")
	_check(_events.has(NarrationEvents.MANY_FIRED_CANNON), "MANY_FIRED_CANNON narration event")
	var shots := [0]
	var counter = load(CannonScript).new(98, LargeObjectPlacement.new(&"cannon", Rect2i(Vector2i(5, 5), Vector2i.ONE)), cannons.config,
			func(_x) -> void: shots[0] += 1)
	var held: float = cannons.config.autofire_delay + 0.01
	counter.interact_held(1.0 / 30.0, held)  # starts autofire (one shot)
	for i in 60:
		held += 1.0 / 30.0
		counter.interact_held(1.0 / 30.0, held)
	var single_rate: int = shots[0]
	shots[0] = 0
	counter.interact_released(held, false)
	counter.rate_multiplier = cannons.config.many_rate_multiplier
	held = cannons.config.autofire_delay + 0.01
	counter.interact_held(1.0 / 30.0, held)
	for i in 60:
		held += 1.0 / 30.0
		counter.interact_held(1.0 / 30.0, held)
	_check(shots[0] >= 2 * single_rate - 2, "autofire about twice as fast (%d vs %d)" % [shots[0], single_rate])

	# --- Language top limit. ---
	var lang = main.get_node("LanguageProgress")
	var db = main.get_node("GameDatabase")
	var id: String = String(lang.config.start_language)
	save.progress.language_understanding[id] = 50.0
	db.tables_loaded.emit({"player_language": [{"language": id, "understanding": 50.0, "max": 30.0}]})
	_check(is_equal_approx(lang.percent(StringName(id)), 30.0), "a value over the limit comes down to it (%s)" % lang.percent(StringName(id)))
	lang.add_percent(10.0)
	_check(is_equal_approx(lang.percent(StringName(id)), 30.0), "gains stop at the limit")
	db.tables_loaded.emit({"player_language": [{"language": id, "understanding": 30.0, "max": -1.0}]})
	lang.add_percent(10.0)
	_check(is_equal_approx(lang.percent(StringName(id)), 40.0), "no limit again with max -1")

	# --- Live god edits (task-078): only reloads after the startup read, and never the game's own values. ---
	db.online = true
	db.server_loads = 1
	db.tables_loaded.emit({"player_language": [{"language": id, "understanding": 66.0, "max": -1.0}]})
	_check(is_equal_approx(lang.percent(StringName(id)), 40.0), "the startup read does not overwrite the save")
	db.server_loads = 2
	db.tables_loaded.emit({"player_language": [{"language": id, "understanding": 66.0, "max": -1.0}]})
	_check(is_equal_approx(lang.percent(StringName(id)), 66.0), "a god edit is adopted (%s)" % lang.percent(StringName(id)))
	_check(is_equal_approx(float(save.progress.language_understanding[id]), 66.0), "the adopted value is in the save")
	lang.add_percent(1.0)
	db.tables_loaded.emit({"player_language": [{"language": id, "understanding": 66.0, "max": -1.0}]})
	_check(is_equal_approx(lang.percent(StringName(id)), 67.0), "a stale value the game sent is not adopted")
	db.tables_loaded.emit({"player_language": [{"language": "JP_KANA", "understanding": 50.0, "max": -1.0}]})
	_check(lang.percent(&"JP_KANA") == 0.0 or lang.is_unlocked(&"JP_KANA"), "locked languages are left alone")
	db.online = false

	main.queue_free()
	await process_frame
	Support.remove_file(save_path)
