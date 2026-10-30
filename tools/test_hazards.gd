extends SceneTree
## Headless test of hazard death (task-012) on the real main scene: spikes end the run once,
## corruption erodes / recovers / kills at the threshold, nothing fires outside PLAYING, the
## game never pauses and the next run starts by itself.
## Usage: godot --headless --path . -s tools/test_hazards.gd

const PHASE_INTRO := 0
const PHASE_PLAYING := 1
const PHASE_DYING := 2
const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "hazards"
const RESTART_DELAY := 0.5

var _failures: PackedStringArray = []
var _requests: Array[StringName] = []
var _ended: Array[StringName] = []
var _erosion: Array[float] = []
var _lethal: Array[StringName] = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _first_cell(loader: MapLoader, type: StringName) -> Vector2i:
	for y in loader.data.height:
		for x in loader.data.width:
			if loader.data.type_at(Vector2i(x, y)) == type:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _put(player: CharacterBody3D, loader: MapLoader, cell: Vector2i) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = loader.cell_to_world(cell)


func _wait_playing(runs: Node, timeout: float) -> void:
	var waited: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and waited < timeout:
		await _wait(0.05)
		waited += 0.05


func _run() -> void:
	var bus: Node = root.get_node("SignalBus")
	bus.connect("run_end_requested", func(c: StringName) -> void: _requests.append(c))
	bus.connect("run_ended", func(c: StringName) -> void: _ended.append(c))
	bus.connect("erosion_changed", func(a: float, _t: Color) -> void: _erosion.append(a))
	bus.connect("hazard_lethal", func(c: StringName, _t: Color) -> void: _lethal.append(c))

	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	Support.isolate_save(main, SAVE_TAG)
	var intro := IntroConfig.new()
	intro.black_hold = 0.5
	intro.wave_fade_in = 0.1
	intro.wave_hold = 0.1
	intro.reveal_duration = 0.1
	main.get_node("IntroSequence").set("config", intro)
	var run_cfg: RunConfig = (main.get_node("RunManager").get("config") as RunConfig).duplicate()
	run_cfg.restart_delay = RESTART_DELAY
	main.get_node("RunManager").set("config", run_cfg)
	root.add_child(main)
	var runs: Node = main.get_node("RunManager")
	var player: CharacterBody3D = main.get_node("Player")
	var loader: MapLoader = main.get_node("World/MapLoader")
	var spawn: Vector3 = loader.spawn_position
	var spike_cell: Vector2i = _first_cell(loader, MapLegend.SPIKES)
	var corrupt_cell: Vector2i = _first_cell(loader, MapLegend.CORRUPT)
	_check(spike_cell.x >= 0 and corrupt_cell.x >= 0, "map has no spikes or corrupting cells")

	# --- Data-driven definitions. ---
	var spikes_def: HazardDefinition = loader.legend.hazards.get(MapLegend.SPIKES)
	var corrupt_def: HazardDefinition = loader.legend.hazards.get(MapLegend.CORRUPT)
	_check(spikes_def != null and spikes_def.lethal_on_touch and spikes_def.end_cause == &"spikes", "spikes definition missing or wrong")
	_check(corrupt_def != null and not corrupt_def.lethal_on_touch and corrupt_def.end_cause == &"corruption", "corruption definition missing or wrong")
	_check(corrupt_def.erosion_rate > 0.0 and corrupt_def.erosion_threshold > 0.0, "corruption rate/threshold must come from the resource")
	_check(loader.legend.hazards.size() == 2, "M1 has exactly two hazard types, got %d" % loader.legend.hazards.size())

	# --- Nothing fires outside PLAYING (still in the intro). ---
	await _wait(0.2)
	_check(runs.get("phase") == PHASE_INTRO, "should still be in the intro")
	_put(player, loader, spike_cell)
	await _wait(0.2)
	_check(_requests.is_empty() and _ended.is_empty(), "hazard fired during INTRO: %s" % [_requests])

	await _wait_playing(runs, 3.0)
	_check(runs.get("phase") == PHASE_PLAYING, "run should be playing after the intro")
	await _wait(0.1)
	_check(_requests.is_empty(), "spawn must not be hazardous / earlier teleport must not leak: %s" % [_requests])
	_check(player.global_position.distance_to(spawn) < 0.5, "player should be at the spawn")

	# --- Spikes: unrevealed, still lethal; end once. ---
	var reveal: Node = main.get_node("MapReveal")
	_check(reveal.call("state_of", spike_cell) == 0 and (reveal.call("mask_at", spike_cell) as Color).r == 0.0,
			"spike cell should be hidden (unrevealed, mask draws nothing) before the player touches it")
	_put(player, loader, spike_cell)
	await _wait(0.2)
	_check(_requests == [&"spikes"], "spikes should request exactly one end, got %s" % [_requests])
	_check(_ended == [&"spikes"], "run_ended(spikes) expected, got %s" % [_ended])
	_check(_lethal == [&"spikes"], "hazard_lethal(spikes) expected, got %s" % [_lethal])
	_check(runs.get("phase") == PHASE_DYING, "phase should be DYING during the restart delay")
	_check(not paused, "tree must not be paused on death")
	await _wait(RESTART_DELAY * 0.5)
	_check(_requests == [&"spikes"], "no second end request while dying, got %s" % [_requests])
	await _wait_playing(runs, 2.0)
	_check(runs.get("phase") == PHASE_PLAYING and runs.get("run_count") == 2, "next run must start by itself")
	_check(player.global_position.distance_to(spawn) < 0.5, "player should be back at the spawn")
	await _wait(0.2)
	_check(_requests == [&"spikes"], "new run at spawn must not end again, got %s" % [_requests])
	_check(not paused, "tree must not be paused after restart")

	# --- Corruption: erodes inside, recovers outside, kills at the threshold. ---
	corrupt_def.erosion_rate = 2.0
	corrupt_def.erosion_threshold = 1.0
	corrupt_def.recovery_rate = 2.0
	_erosion.clear()
	_put(player, loader, corrupt_cell)
	await _wait(0.25)
	var state: RunState = runs.get("state")
	var mid: float = state.erosion
	_check(mid > 0.0 and mid < corrupt_def.erosion_threshold, "erosion should be partial after 0.25s, got %f" % mid)
	_check(_requests == [&"spikes"], "partial erosion must not end the run: %s" % [_requests])
	_check(not _erosion.is_empty() and _erosion[_erosion.size() - 1] > 0.0 and _erosion[_erosion.size() - 1] < 1.0, "erosion_changed should report a partial amount")
	_put(player, loader, loader.world_to_cell(spawn))
	await _wait(0.1)
	_check(state.erosion < mid, "erosion should recover outside the area (%f -> %f)" % [mid, state.erosion])
	await _wait(0.5)
	_check(is_zero_approx(state.erosion), "erosion should recover to zero, got %f" % state.erosion)
	_check(_erosion[_erosion.size() - 1] == 0.0, "erosion_changed should end at 0")
	_put(player, loader, corrupt_cell)
	await _wait(1.0)
	_check(_requests == [&"spikes", &"corruption"], "corruption should end the run once, got %s" % [_requests])
	_check(_ended == [&"spikes", &"corruption"], "run_ended(corruption) expected, got %s" % [_ended])
	_check(_erosion.has(1.0), "erosion_changed should reach 1.0")
	await _wait_playing(runs, 2.0)
	_check(runs.get("phase") == PHASE_PLAYING and runs.get("run_count") == 3, "run 3 should start by itself")
	_check(is_zero_approx((runs.get("state") as RunState).erosion), "erosion must not leak into the next run")
	await _wait(0.2)
	_check(_requests == [&"spikes", &"corruption"], "no extra end requests, got %s" % [_requests])

	main.queue_free()
	await process_frame
	Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
	if _failures.is_empty():
		print("PASS test_hazards")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_hazards")
		quit(1)
