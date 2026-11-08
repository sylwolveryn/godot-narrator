extends SceneTree
## Headless test of god's live Reveal map: DevBridge turns a new reveal_map counter in the flag file into
## SignalBus.dev_reveal_map_requested (the value found at start is only remembered), and MapReveal in the running main
## scene shows every drawn cell of the loaded map as seen and records them in the progress.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_dev_reveal_live.gd

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "dev_reveal_live"
const FLAGS := "user://test_dev_flags_live.cfg"
const MAP := "res://data/maps/m1_awakening.txt"
const PHASE_PLAYING := 1
const CELL_SEEN := 2

var _failures: PackedStringArray = []
var _requests: int = 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _write_flags(counter: int) -> void:
	var f := FileAccess.open(FLAGS, FileAccess.WRITE)
	f.store_string("[overlay]\n\nperf=false\n\n[commands]\n\nreveal_map=%d\n" % counter)
	f.close()


func _run() -> void:
	# Autoloads are not compile-time identifiers in a SceneTree script: reach the bus through the tree.
	root.get_node("SignalBus").connect(&"dev_reveal_map_requested", func() -> void: _requests += 1)
	_check_bridge()
	_requests = 0
	await _check_scene()
	Support.remove_file(FLAGS)
	if _failures.is_empty():
		print("PASS test_dev_reveal_live")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_dev_reveal_live")
		quit(1)


func _check_bridge() -> void:
	var bridge: Node = load("res://scripts/core/dev_bridge.gd").new()
	bridge.set("flags_path", FLAGS)
	_write_flags(7)
	bridge.call("_poll")
	_check(_requests == 0, "the counter present at start must not fire")
	bridge.call("_poll")
	_check(_requests == 0, "an unchanged file must not fire")
	_write_flags(8)
	bridge.call("_poll")
	_check(_requests == 1, "a new counter fires once (got %d)" % _requests)
	bridge.call("_poll")
	_check(_requests == 1, "the same counter does not fire again")
	bridge.free()


func _check_scene() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var save_path: String = Support.isolate_save(main, SAVE_TAG)
	var loader: MapLoader = main.get_node("World/MapLoader")
	loader.map_path = MAP
	loader.use_cmdline_map = false
	root.add_child(main)
	var runs: Node = main.get_node("RunManager")
	var guard: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 5.0:
		await create_timer(0.1).timeout
		guard += 0.1
	await create_timer(0.2).timeout
	var reveal = main.get_node("MapReveal")
	var seen_before: int = 0
	for cell: Vector2i in loader.drawn_cells:
		if reveal.state_of(cell) == CELL_SEEN:
			seen_before += 1
	_check(seen_before < loader.drawn_cells.size(), "the map starts partly hidden")

	root.get_node("SignalBus").emit_signal(&"dev_reveal_map_requested")
	await process_frame
	var seen_after: int = 0
	for cell: Vector2i in loader.drawn_cells:
		if reveal.state_of(cell) == CELL_SEEN:
			seen_after += 1
	_check(seen_after == loader.drawn_cells.size(), "every drawn cell seen after the request (%d of %d)" % [seen_after, loader.drawn_cells.size()])
	var saved: PackedVector2Array = main.get_node("SaveService").call("get_revealed_cells", loader.map_id)
	_check(saved.size() == loader.drawn_cells.size(), "every drawn cell recorded in the progress (%d)" % saved.size())

	main.queue_free()
	await process_frame
	Support.remove_file(save_path)
