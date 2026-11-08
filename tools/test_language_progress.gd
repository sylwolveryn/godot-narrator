extends SceneTree
## Headless test of the language understanding progression (task-065): a new save starts at EN_GB 0% (unlocked and
## selected, announced once, mirrored to the DB); 20 tiles walked = +1%; a run end = +1%; the first discovery of a cell
## type = +3% once (void never, spawn counts as floor, a pushable start cell as object); values clamp at 100; at 60%+ a
## Language list request unlocks the next language at 1% with exactly one glyph storm per request; selecting a language
## announces it with its own understanding; everything persists through SaveService; a loaded save is repaired; a
## deleted save (god "Start new game") restarts at EN_GB 0% and pushes 0 to the DB.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_language_progress.gd

const Support := preload("res://tools/test_support.gd")
const PATH := "user://test_progress_language.tres"
const REDUCER := "set_language_understanding"
const SPY_SOURCE := "extends \"res://scripts/data/game_database.gd\"\nvar calls: Array = []\nfunc call_reducer(reducer: String, args: Array = []) -> void:\n\tcalls.append([reducer, args])\n"

var _failures: PackedStringArray = []
var _changed: Array = []
var _selected: Array = []
var _unlocked: Array = []
var _storms: Array = []
var _cfg: LanguageConfig
var _spy_script: GDScript
var _spies: Array[Node] = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _service() -> Node:
	var cfg := SaveConfig.new()
	cfg.save_path = PATH
	var svc: Node = load("res://scripts/core/save_service.gd").new()
	svc.set("config", cfg)
	root.add_child(svc)
	return svc


## A 6x1 map: floor, wall, void, spawn, pushable start (floor), item.
func _loader() -> Node:
	var loader: Node = load("res://scripts/world/map_loader.gd").new()
	var data := MapData.new()
	data.width = 6
	data.height = 1
	var types: Array[StringName] = [MapLegend.FLOOR, MapLegend.WALL, MapLegend.VOID, MapLegend.SPAWN, MapLegend.FLOOR, MapLegend.ITEM]
	data.types = types
	data.objects = [Vector2i(4, 0)]
	loader.set("data", data)
	return loader


func _spy() -> Node:
	var db: Node = _spy_script.new()
	_spies.append(db)
	return db


func _progress_node(svc: Node, loader: Node, db: Node, player: Node3D) -> Node:
	var lp: Node = load("res://scripts/core/language_progress.gd").new()
	lp.set("config", _cfg)
	lp.set("save_service", svc)
	lp.set("map_loader", loader)
	lp.set("database", db)
	lp.set("player", player)
	root.add_child(lp)
	return lp


func _pushes(db: Node, language: String) -> Array:
	var out: Array = []
	for c: Array in db.get("calls"):
		if c[0] == REDUCER and c[1][0] == language:
			out.append(c[1][1])
	return out


func _reveal(cells: Array) -> void:
	var packed := PackedVector2Array()
	for c: Vector2i in cells:
		packed.append(Vector2(c))
	root.get_node("SignalBus").emit_signal("cells_revealed", &"test_map", packed)


func _run() -> void:
	Support.remove_file(PATH)
	_cfg = load("res://resources/config/language_config.tres") as LanguageConfig
	_check(_cfg != null, "language_config.tres loads")
	_check(_cfg.start_language == &"EN_GB" and _cfg.start_percent == 0.0 and _cfg.max_percent == 100.0, "config start EN_GB 0 / max 100")
	_check(_cfg.tiles_per_percent == 20 and _cfg.percent_per_death == 1.0 and _cfg.percent_per_new_type == 3.0, "config gains 20 tiles / 1 death / 3 new type")
	_check(_cfg.unlock_at_percent == 60.0 and _cfg.unlocked_start_percent == 1.0 and _cfg.unlock_order[0] == "HU_HU", "config unlock 60 -> HU_HU at 1")
	_spy_script = GDScript.new()
	_spy_script.source_code = SPY_SOURCE
	_check(_spy_script.reload() == OK, "DB spy compiles")
	var bus: Node = root.get_node("SignalBus")
	bus.connect("language_understanding_changed", func(l: StringName, u: float) -> void: _changed.append([l, u]))
	bus.connect("language_selected", func(l: StringName) -> void: _selected.append(l))
	bus.connect("language_unlocked", func(l: StringName) -> void: _unlocked.append(l))
	bus.connect("glyph_storm_requested", func(c: Vector3, _r: float, _d: float, _t: Color) -> void: _storms.append(c))

	var player := Node3D.new()
	root.add_child(player)
	player.global_position = Vector3(3.0, 0.0, 5.0)
	var loader: Node = _loader()

	# --- new save: EN_GB 0% unlocked + selected, announced once after ready, every language pushed to the DB ---
	var svc: Node = _service()
	var db: Node = _spy()
	var lp: Node = _progress_node(svc, loader, db, player)
	await process_frame
	var p: PersistentProgress = svc.get("progress")
	_check(lp.call("selected_language") == &"EN_GB" and p.selected_language == "EN_GB", "new save selects EN_GB")
	_check(p.unlocked_languages == PackedStringArray(["EN_GB"]), "new save unlocks EN_GB only: %s" % [p.unlocked_languages])
	_check(lp.call("percent", &"EN_GB") == 0.0, "new save EN_GB at 0%")
	_check(_selected == [&"EN_GB"], "language_selected(EN_GB) announced once: %s" % [_selected])
	_check(_changed.size() == 1 and _changed[0] == [&"EN_GB", 0.0], "language_understanding_changed(EN_GB, 0) announced: %s" % [_changed])
	_check(_pushes(db, "EN_GB") == [0.0], "EN_GB 0 pushed to the DB on load: %s" % [db.get("calls")])
	_check(_pushes(db, "HU_HU") == [0.0], "locked languages pushed as 0 on load")

	# --- walking: 40 cells = +2%, pushed when the whole percent changes, not per step ---
	_changed.clear()
	var calls_before: int = (db.get("calls") as Array).size()
	for i in 19:
		bus.emit_signal("player_stepped", Vector2i(i, 0))
	_check(lp.call("percent", &"EN_GB") == 0.0 and p.language_step_remainder == 19, "19 steps give nothing yet")
	_check((db.get("calls") as Array).size() == calls_before, "no DB call per step")
	for i in 21:
		bus.emit_signal("player_stepped", Vector2i(i, 1))
	_check(lp.call("percent", &"EN_GB") == 2.0, "40 steps = +2%% (%.1f)" % lp.call("percent", &"EN_GB"))
	_check(p.language_step_remainder == 0, "step remainder back to 0")
	_check(_pushes(db, "EN_GB") == [0.0, 1.0, 2.0], "DB gets 1 then 2: %s" % [_pushes(db, "EN_GB")])
	_check(_changed.size() == 2 and is_equal_approx(_changed[-1][1], 0.02), "understanding_changed per gain, 0..1: %s" % [_changed])

	# --- a run end (death) = +1% ---
	bus.emit_signal("run_ended", &"test")
	_check(lp.call("percent", &"EN_GB") == 3.0, "a run end = +1%")

	# --- discoveries: +3% the first time a type is seen; void never; spawn = floor; pushable start = object ---
	_reveal([Vector2i(0, 0)])
	_check(lp.call("percent", &"EN_GB") == 6.0, "first floor = +3%")
	_reveal([Vector2i(3, 0)])
	_check(lp.call("percent", &"EN_GB") == 6.0, "spawn counts as floor (already seen): nothing")
	_reveal([Vector2i(2, 0)])
	_check(lp.call("percent", &"EN_GB") == 6.0, "void never counts")
	_reveal([Vector2i(1, 0), Vector2i(4, 0)])
	_check(lp.call("percent", &"EN_GB") == 12.0, "wall + object in one reveal = +6%% (%.1f)" % lp.call("percent", &"EN_GB"))
	_reveal([Vector2i(1, 0), Vector2i(0, 0)])
	_check(lp.call("percent", &"EN_GB") == 12.0, "seen types again: nothing")
	_check(p.discovered_types == PackedStringArray(["floor", "wall", "object"]), "discovered types stored: %s" % [p.discovered_types])

	# --- below the unlock threshold a list request unlocks nothing ---
	bus.emit_signal("language_list_requested")
	_check(_unlocked.is_empty() and _storms.is_empty(), "no unlock below 60%")

	# --- clamp at 100 ---
	lp.call("add_percent", 87.0)
	_check(lp.call("percent", &"EN_GB") == 99.0, "add 87 -> 99")
	_reveal([Vector2i(5, 0)])
	_check(lp.call("percent", &"EN_GB") == 100.0, "item discovery clamps at 100 (%.1f)" % lp.call("percent", &"EN_GB"))
	bus.emit_signal("run_ended", &"test")
	_check(lp.call("percent", &"EN_GB") == 100.0, "stays at 100")

	# --- at 60%+: one list request = one unlock at 1% + one storm around the player ---
	bus.emit_signal("language_list_requested")
	_check(_unlocked == [&"HU_HU"], "HU_HU unlocked once: %s" % [_unlocked])
	_check(lp.call("percent", &"HU_HU") == 1.0 and p.unlocked_languages == PackedStringArray(["EN_GB", "HU_HU"]), "HU_HU at 1%")
	_check(_storms.size() == 1 and (_storms[0] as Vector3).is_equal_approx(player.global_position), "one storm at the player: %s" % [_storms])
	_check(_pushes(db, "HU_HU").back() == 1.0, "HU_HU 1 pushed to the DB")
	_check((lp.call("entry_labels") as PackedStringArray) == PackedStringArray(["English 100%", "Hungarian 1%"]), "menu entries: %s" % [lp.call("entry_labels")])

	# --- selecting announces the language and its own understanding; gains go to it ---
	_selected.clear()
	_changed.clear()
	bus.emit_signal("language_select_requested", &"ALIEN")
	_check(_selected.is_empty() and lp.call("selected_language") == &"EN_GB", "a locked language cannot be selected")
	bus.emit_signal("language_select_requested", &"HU_HU")
	_check(_selected == [&"HU_HU"] and lp.call("selected_language") == &"HU_HU", "language_selected(HU_HU): %s" % [_selected])
	_check(_changed.size() == 1 and _changed[0][0] == &"HU_HU" and is_equal_approx(_changed[0][1], 0.01), "understanding_changed(HU_HU, 0.01): %s" % [_changed])
	bus.emit_signal("run_ended", &"test")
	_check(lp.call("percent", &"HU_HU") == 2.0 and lp.call("percent", &"EN_GB") == 100.0, "gains go to the selected language")
	_storms.clear()
	bus.emit_signal("language_list_requested")
	_check(_storms.is_empty() and _unlocked.size() == 1, "HU_HU at 2% unlocks nothing")
	for i in 7:
		bus.emit_signal("player_stepped", Vector2i(i, 2))

	# --- persistence through SaveService ---
	svc.call("save_if_dirty")
	lp.free()
	svc.free()
	_selected.clear()
	_changed.clear()
	svc = _service()
	db = _spy()
	lp = _progress_node(svc, loader, db, player)
	await process_frame
	p = svc.get("progress")
	_check(lp.call("selected_language") == &"HU_HU", "selection persisted")
	_check(lp.call("percent", &"EN_GB") == 100.0 and lp.call("percent", &"HU_HU") == 2.0, "understanding persisted")
	_check(p.unlocked_languages == PackedStringArray(["EN_GB", "HU_HU"]), "unlocked list persisted")
	_check(p.discovered_types == PackedStringArray(["floor", "wall", "object", "item"]), "discovered types persisted: %s" % [p.discovered_types])
	_check(p.language_step_remainder == 7, "step remainder persisted (%d)" % p.language_step_remainder)
	_check(_selected == [&"HU_HU"] and _changed.size() == 1 and is_equal_approx(_changed[0][1], 0.02), "load announces HU_HU at 0.02")
	_check(_pushes(db, "EN_GB") == [100.0] and _pushes(db, "HU_HU") == [2.0], "load pushes the saved values to the DB")
	# Run start announces again.
	_selected.clear()
	bus.emit_signal("run_started", 0)
	_check(_selected == [&"HU_HU"], "run start announces the selection")
	lp.free()
	svc.free()

	# --- a tampered save is repaired ---
	var tampered := PersistentProgress.new()
	tampered.selected_language = "KLINGON"
	tampered.unlocked_languages = PackedStringArray(["HU_HU", "KLINGON", "HU_HU"])
	tampered.language_understanding = {"HU_HU": 250.0, "KLINGON": 5.0}
	tampered.language_step_remainder = 45
	ResourceSaver.save(tampered, PATH)
	svc = _service()
	lp = _progress_node(svc, loader, _spy(), player)
	await process_frame
	p = svc.get("progress")
	_check(p.unlocked_languages == PackedStringArray(["EN_GB", "HU_HU"]), "repair: start language kept, unknown dropped: %s" % [p.unlocked_languages])
	_check(p.selected_language == "EN_GB", "repair: unknown selection falls back to EN_GB")
	_check(lp.call("percent", &"HU_HU") == 100.0 and lp.call("percent", &"EN_GB") == 0.0 and not p.language_understanding.has("KLINGON"), "repair: clamped, defaults filled: %s" % [p.language_understanding])
	_check(p.language_step_remainder < _cfg.tiles_per_percent, "repair: step remainder below the quota")
	lp.free()
	svc.free()

	# --- god "Start new game" deletes the save: EN_GB 0% again, pushed to the DB ---
	Support.remove_file(PATH)
	svc = _service()
	db = _spy()
	lp = _progress_node(svc, loader, db, player)
	await process_frame
	_check(lp.call("selected_language") == &"EN_GB" and lp.call("percent", &"EN_GB") == 0.0, "deleted save restarts at EN_GB 0%")
	_check(_pushes(db, "EN_GB") == [0.0] and _pushes(db, "HU_HU") == [0.0], "new game pushes 0 to the DB")
	lp.free()
	svc.free()
	Support.remove_file(PATH)

	# --- the real GameDatabase with the link disabled drops calls (no crash) ---
	var real_db: Node = load("res://scripts/data/game_database.gd").new()
	var off := DbConfig.new()
	off.enabled = false
	real_db.set("config", off)
	real_db.call("call_reducer", REDUCER, ["EN_GB", 1.0])
	real_db.free()

	player.free()
	loader.free()
	for spy in _spies:
		spy.free()
	_spies.clear()
	if _failures.is_empty():
		print("PASS test_language_progress")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_language_progress")
		quit(1)
