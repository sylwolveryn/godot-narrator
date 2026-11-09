extends SceneTree
## Headless test of task-091: a fully discovered map is announced and saved; two teleport trips are counted; together
## they unlock the brain (BRAIN_UNLOCKED) and the menu offers "become the brain" as new; the brain form shows the 2x2
## glyph block (cycling glyphs) and the aura (3..9 tiles); interact with nothing in reach selects the next language;
## the menu item switches back to the single glyph.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_brain.gd

const Support := preload("res://tools/test_support.gd")
const MAP := "res://data/maps/m1_awakening.txt"
const PHASE_PLAYING := 1

var _failures: PackedStringArray = []
var _events: Array[StringName] = []
var _complete: Array[StringName] = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var save_path: String = Support.isolate_save(main, "brain")
	var seeded := PersistentProgress.new()
	seeded.death_count = 3
	seeded.run_count = 3
	seeded.menu_unlocked = true
	seeded.identity_glyph = "Q"
	seeded.unlocked_languages = PackedStringArray(["EN_GB", "HU_HU", "DREAM"])
	seeded.language_understanding = {"EN_GB": 10.0, "HU_HU": 10.0, "DREAM": 10.0}
	seeded.selected_language = "EN_GB"
	ResourceSaver.save(seeded, save_path)
	var loader = main.get_node("World/MapLoader")
	loader.map_path = MAP
	loader.use_cmdline_map = false
	root.add_child(main)
	var bus: Node = root.get_node("SignalBus")
	bus.connect(&"narration_event", func(e: StringName) -> void: _events.append(e))
	bus.connect(&"map_fully_revealed", func(m: StringName) -> void: _complete.append(m))
	var runs = main.get_node("RunManager")
	var guard: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 5.0:
		await create_timer(0.1).timeout
		guard += 0.1
	var save = main.get_node("SaveService")
	var entity = main.get_node("EntityProgression")
	var menu = main.get_node("MenuController")
	var brain_view = main.get_node("BrainView")
	var world_view = main.get_node("GlyphWorldView")
	var lang = main.get_node("LanguageProgress")

	_check(not entity.is_brain_unlocked(), "locked at first")
	_check(not menu.current_labels().has("become the brain"), "no brain item while locked")
	bus.emit_signal(&"teleport_arrived", Vector3.ZERO, 1)
	bus.emit_signal(&"teleport_arrived", Vector3.ZERO, 1)
	_check(save.progress.teleport_count == 2, "two teleport trips counted")
	_check(not entity.is_brain_unlocked(), "teleports alone do not unlock it")
	bus.emit_signal(&"dev_reveal_map_requested")
	await process_frame
	_check(_complete.has(&"m1_awakening"), "the fully discovered map is announced")
	_check(save.progress.complete_maps.has("m1_awakening"), "and saved")
	_check(entity.is_brain_unlocked(), "a complete map and two trips unlock the brain")
	_check(_events.has(NarrationEvents.BRAIN_UNLOCKED), "the unlock narrates")
	_check(menu.current_labels().has("become the brain"), "the menu offers the brain")
	_check(menu.has_new_items(), "announced as new (pulse)")

	_events.clear()
	bus.emit_signal(&"menu_action_requested", MenuItemDef.ACTION_BRAIN)
	await process_frame
	_check(entity.current_form() == EntityForm.BRAIN, "the brain form is taken")
	# The narrator takes form changes straight from entity_form_changed (no narration_event signal).
	var narrator = main.get_node("Narrator")
	narrator.advance(0.05)
	var pending: Array = [narrator.current, narrator.queued] + narrator.waiting()
	_check(pending.any(func(b): return b != null and b.event == NarrationEvents.TRANSFORMED_TO_BRAIN), "becoming the brain narrates")
	_check(brain_view.is_shown(), "the 2x2 block shows")
	_check(world_view.is_aura_on(), "the aura glows")
	var first: PackedStringArray = brain_view.glyphs()
	_check(first.size() == 4 and not first.has(""), "four glyphs")
	var radii: Array[float] = []
	for i in 40:
		await create_timer(0.1).timeout
		var geo: Vector4 = loader.surface_material.get_shader_parameter(&"aura_geo")
		radii.append(geo.z / loader.world_config.cell_size)
	_check(brain_view.glyphs() != first, "the glyphs keep changing")
	_check(radii.min() >= 2.99 and radii.max() <= 9.01 and radii.max() - radii.min() > 2.0, "the aura breathes within 3..9 tiles (%.2f..%.2f)" % [radii.min(), radii.max()])
	_check(menu.current_labels().has("become one"), "in the brain the item reads become one")

	# Interact with nothing in reach: the next language.
	var interact = main.get_node("Interactables")
	var press := InputEventAction.new()
	press.action = interact.config.action
	press.pressed = true
	_events.clear()
	interact._input(press)
	_check(lang.selected_language() == &"HU_HU", "interact selects the next language (%s)" % lang.selected_language())
	_check(_events.has(NarrationEvents.BRAIN_LANGUAGE_SHIFT), "the shift narrates")
	interact._input(press)
	interact._input(press)
	_check(lang.selected_language() == &"EN_GB", "it wraps around the unlocked languages")

	bus.emit_signal(&"menu_action_requested", MenuItemDef.ACTION_BRAIN)
	await process_frame
	_check(entity.current_form() == EntityForm.SINGLE, "the item switches back to the single glyph")
	_check(not brain_view.is_shown() and not world_view.is_aura_on(), "block and aura gone")

	main.queue_free()
	await process_frame
	Support.remove_file(save_path)
	if _failures.is_empty():
		print("PASS test_brain")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_brain")
		quit(1)
