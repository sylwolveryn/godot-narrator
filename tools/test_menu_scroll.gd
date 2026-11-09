extends SceneTree
## Headless test of task-086: the menu window over long lists (window_for, selection moving the window, wrap-around in
## MenuController, pointer indices of the whole list) and the menu scale following the camera zoom.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_menu_scroll.gd

const Support := preload("res://tools/test_support.gd")
const MAP := "res://data/maps/m1_awakening.txt"
const PHASE_PLAYING := 1
const VIEW_SCRIPT := "res://scripts/rendering/menu_glyph_view.gd"

var _failures: PackedStringArray = []
var _pointed: Array = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	# Pure window rule (loaded at run time: the view uses autoloads).
	var ViewScript = load(VIEW_SCRIPT)
	_check(ViewScript.window_for(3, 0, 5, 7) == 0, "a short list never scrolls")
	_check(ViewScript.window_for(6, 0, 12, 7) == 0, "the last visible row keeps the window")
	_check(ViewScript.window_for(7, 0, 12, 7) == 1, "one past the window scrolls by one")
	_check(ViewScript.window_for(11, 0, 12, 7) == 5, "wrapping to the last row shows the bottom window")
	_check(ViewScript.window_for(0, 5, 12, 7) == 0, "wrapping to the first row shows the top window")
	_check(ViewScript.window_for(6, 5, 12, 7) == 5, "inside the window: no move")

	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var save_path: String = Support.isolate_save(main, "menu_scroll")
	var loader = main.get_node("World/MapLoader")
	loader.map_path = MAP
	loader.use_cmdline_map = false
	root.add_child(main)
	var runs = main.get_node("RunManager")
	var guard: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 5.0:
		await create_timer(0.1).timeout
		guard += 0.1
	var view = main.get_node("MenuGlyphView")
	var rig = main.get_node("CameraRig")
	var bus: Node = root.get_node("SignalBus")
	var labels := PackedStringArray()
	for i in 12:
		labels.append("item %d" % i)
	bus.emit_signal(&"menu_opened", labels, 0)
	await process_frame
	_check(view.window_first() == 0, "opens at the top")
	bus.emit_signal(&"menu_selection_changed", 11)
	var shown: int = view._visible_rows()
	_check(shown >= 1 and shown < 12, "a 12-row list is windowed (%d rows shown)" % shown)
	_check(view.window_first() == 12 - shown, "selecting the last row shows the bottom window (%d)" % view.window_first())
	_check(view.item_screen_position(11) != Vector2.ZERO and view.item_screen_position(0) == Vector2.ZERO, "only rows in the window have a screen position")
	bus.emit_signal(&"menu_selection_changed", 0)
	_check(view.window_first() == 0, "wrapping to the first row shows the top window")

	# Scale follows the zoom, live while open.
	var z0: float = rig.current_zoom()
	await process_frame
	var fit: float = view.menu_scale() / z0
	_check(fit > 0.0 and fit <= 1.0 and fit >= view.config.min_fit_scale - 0.001, "menu scale = camera zoom x fit (%s)" % fit)
	rig.override_view(main.get_node("Player").global_position, rig.view_config.zoom_max)
	await process_frame
	await process_frame
	_check(is_equal_approx(view.menu_scale(), rig.view_config.zoom_max * fit), "zooming out while open grows the menu with it (%s)" % view.menu_scale())
	rig.release_override()
	bus.emit_signal(&"menu_closed")

	# MenuController: moving up from the first item wraps to the last.
	var menu = main.get_node("MenuController")
	var save = main.get_node("SaveService")
	save.progress.menu_unlocked = true
	if menu.open():
		var count: int = menu.current_labels().size()
		menu.move_selection(-1)
		_check(menu.selected_index() == count - 1, "up from the first item selects the last")
		menu.move_selection(1)
		_check(menu.selected_index() == 0, "down from the last item selects the first")
		menu.close()
	else:
		_failures.append("the menu did not open")

	main.queue_free()
	await process_frame
	Support.remove_file(save_path)
	if _failures.is_empty():
		print("PASS test_menu_scroll")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_menu_scroll")
		quit(1)
