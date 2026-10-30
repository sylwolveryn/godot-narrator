extends SceneTree
## Headless test: forces a run end and asserts a clean restart.
## Usage: godot --headless --path . -s tools/test_run_manager.gd

var _failures: PackedStringArray = []
var _started: Array[int] = []
var _ended: Array[StringName] = []


func _init() -> void:
	# Autoloads are registered after _init; run on the first frame.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	var bus: Node = root.get_node("SignalBus")
	bus.connect("run_started", func(i: int) -> void: _started.append(i))
	bus.connect("run_ended", func(c: StringName) -> void: _ended.append(c))

	var cfg: Resource = load("res://scripts/core/run_config.gd").new()
	cfg.set("restart_delay", 0.0)
	var mgr: Node = load("res://scripts/core/run_manager.gd").new()
	mgr.set("config", cfg)
	root.add_child(mgr)

	mgr.call("start_run")
	var first_state: RefCounted = mgr.get("state")
	first_state.set("elapsed", 42.0)
	_check(_started == [0], "first run_started(0) expected, got %s" % [_started])

	bus.emit_signal("run_end_requested", &"test_cause")
	await process_frame

	_check(_ended == [&"test_cause"], "run_ended(test_cause) expected, got %s" % [_ended])
	_check(_started == [0, 1], "restart run_started(1) expected, got %s" % [_started])
	var new_state: RefCounted = mgr.get("state")
	_check(new_state != first_state, "state object should be fresh")
	_check(float(new_state.get("elapsed")) < 1.0, "elapsed leaked from previous run")
	_check(new_state.get("end_cause") == &"", "end_cause leaked from previous run")
	_check(new_state.get("run_index") == 1, "run_index should be 1")
	_check(mgr.get("phase") == 1, "phase should be PLAYING")

	# With zero delay each end restarts immediately: one start per end, no doubles.
	mgr.call("end_run", &"a")
	mgr.call("end_run", &"b")
	await process_frame
	_check(_started == [0, 1, 2, 3], "expected runs 0..3, got %s" % [_started])
	_check(_ended == [&"test_cause", &"a", &"b"], "unexpected run_ended list %s" % [_ended])

	if _failures.is_empty():
		print("PASS test_run_manager")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_run_manager")
		quit(1)
