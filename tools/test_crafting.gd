extends SceneTree
## Headless test of task-088: Items > dirt opens the crafting page; research spends dirt and teaches the next recipe;
## crafting spends the craft cost and counts it; not enough dirt is refused with CRAFT_REFUSED; back returns to the
## Items list; the stock (consumed - spent) is what the Items list shows.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_crafting.gd

const Support := preload("res://tools/test_support.gd")
const MAP := "res://data/maps/m1_awakening.txt"
const PHASE_PLAYING := 1
const RECIPES := [
	{"id": "dust_lens", "label": "dust lens", "research_order": 1, "research_cost": 20, "craft_cost": 10},
	{"id": "clay_sigil", "label": "clay sigil", "research_order": 2, "research_cost": 40, "craft_cost": 15},
]

var _failures: PackedStringArray = []
var _events: Array[StringName] = []
var _shown: PackedStringArray = PackedStringArray()


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var save_path: String = Support.isolate_save(main, "crafting")
	var seeded := PersistentProgress.new()
	seeded.death_count = 3
	seeded.run_count = 3
	seeded.menu_unlocked = true
	seeded.identity_glyph = "Q"
	ResourceSaver.save(seeded, save_path)
	var loader = main.get_node("World/MapLoader")
	loader.map_path = MAP
	loader.use_cmdline_map = false
	root.add_child(main)
	var bus: Node = root.get_node("SignalBus")
	bus.connect(&"narration_event", func(e: StringName) -> void: _events.append(e))
	bus.connect(&"menu_opened", func(labels: PackedStringArray, _sel: int) -> void: _shown = labels)
	var runs = main.get_node("RunManager")
	var guard: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 5.0:
		await create_timer(0.1).timeout
		guard += 0.1
	main.get_node("GameDatabase").tables["craft_def"] = RECIPES
	var save = main.get_node("SaveService")
	var menu = main.get_node("MenuController")
	var crafting = main.get_node("Crafting")
	for i in 30:
		bus.emit_signal(&"consumed", Consumable.DIRT)
	_check(save.stock(Consumable.DIRT) == 30, "30 dirt in stock")

	_check(menu.open(), "menu opens")
	var labels: PackedStringArray = menu.current_labels()
	menu.move_selection(labels.find("items") - menu.selected_index())
	menu.confirm()
	_check(menu.is_items_shown(), "Items list")
	menu.confirm_items()  # dirt is the first entry
	_check(menu.is_crafting_shown(), "dirt opens the crafting page")
	_check(_shown == PackedStringArray(["research 20", "back"]), "at first only research: %s" % [_shown])

	_events.clear()
	menu.confirm_crafting()  # research
	_check(save.progress.known_crafts == PackedStringArray(["dust_lens"]), "research teaches the first recipe")
	_check(save.stock(Consumable.DIRT) == 10, "research spent 20 dirt (%d left)" % save.stock(Consumable.DIRT))
	_check(_events.has(NarrationEvents.RESEARCH_DONE) and _events.has(NarrationEvents.CRAFT_LEARNED), "research narrates")
	_check(_shown == PackedStringArray(["dust lens 10", "research 40", "back"]), "the new recipe is listed: %s" % [_shown])
	_check(menu.selected_index() == 1, "research stays selected")

	menu.move_selection(-1)
	_events.clear()
	menu.confirm_crafting()  # dust lens
	_check(crafting.crafted(&"dust_lens") == 1, "one dust lens crafted")
	_check(save.stock(Consumable.DIRT) == 0, "crafting spent 10 dirt")
	_check(_events.has(NarrationEvents.CRAFTED), "crafting narrates")
	_events.clear()
	menu.confirm_crafting()
	_check(crafting.crafted(&"dust_lens") == 1, "no dirt: nothing crafted")
	_check(_events.has(NarrationEvents.CRAFT_REFUSED), "no dirt: refused with narration")
	menu.move_selection(1)
	_events.clear()
	menu.confirm_crafting()
	_check(save.progress.known_crafts.size() == 1 and _events.has(NarrationEvents.CRAFT_REFUSED), "research without dirt is refused")

	menu.move_selection(1)  # back
	menu.confirm_crafting()
	_check(menu.is_items_shown() and not menu.is_crafting_shown(), "back returns to the Items list")
	_check(_shown.size() > 0 and _shown[0] == "dirt 0", "the Items list shows the stock: %s" % [_shown])
	_check(save.consumed_count(Consumable.DIRT) == 30, "consumed ever stays 30")
	menu.close()

	main.queue_free()
	await process_frame
	Support.remove_file(save_path)
	if _failures.is_empty():
		print("PASS test_crafting")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_crafting")
		quit(1)
