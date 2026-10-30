extends SceneTree
## Headless test of the narrator (task-014): eligibility, ladder order, class priority, display cap
## with queue / TTL / replacement, death preempt, TIME beats, persisted heard beats, save on quit.
## Time is driven by calling Narrator.advance() so the test is deterministic. Only temporary save
## paths are used; they are removed at the end.
## Usage: godot --headless --path . -s tools/test_narrator.gd

const Support := preload("res://tools/test_support.gd")
const PATH := "user://test_progress_narrator.tres"
const CONFIG_PATH := "res://resources/narration/narrator_config.tres"
const STEP := 0.1

var _failures: PackedStringArray = []
var _bus: Node
var _started: PackedStringArray = []
var _fast_dissolves: int = 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


## SaveService on a temp file plus a Narrator wired to it. `tweak` may adjust the (copied) config.
func _rig(tweak: Callable = Callable(), fresh: bool = true) -> Dictionary:
	if fresh:
		Support.remove_file(PATH)
	var cfg := SaveConfig.new()
	cfg.save_path = PATH
	var svc: Node = load("res://scripts/core/save_service.gd").new()
	svc.set("config", cfg)
	root.add_child(svc)
	var config: NarratorConfig = (load(CONFIG_PATH) as NarratorConfig).duplicate()
	if tweak.is_valid():
		tweak.call(config)
	var narrator: Node = load("res://scripts/narrator/narrator.gd").new()
	narrator.set("config", config)
	narrator.set("save_service", svc)
	root.add_child(narrator)
	_started = PackedStringArray()
	_fast_dissolves = 0
	narrator.connect("beat_started", func(b: NarrationBeat) -> void: _started.append(b.id))
	narrator.connect("beat_dissolving", func(fast: bool) -> void: _fast_dissolves += int(fast))
	return {"svc": svc, "narrator": narrator, "config": config}


func _teardown(rig: Dictionary) -> void:
	(rig["narrator"] as Node).free()
	(rig["svc"] as Node).free()


## Advances `seconds` of narrator time in steps.
func _wait(narrator: Node, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		narrator.call("advance", STEP)
		t += STEP


func _state(narrator: Node) -> int:
	return narrator.get("state")


func _start_run(rig: Dictionary) -> void:
	_bus.emit_signal("run_started", 0)


func _beat(narrator: Node, id: String) -> NarrationBeat:
	for b: NarrationBeat in (narrator.get("config") as NarratorConfig).beats:
		if b.id == id:
			return b
	return null


func _run() -> void:
	_bus = root.get_node("SignalBus")
	Support.remove_file(PATH)
	_test_data()
	_test_eligibility()
	_test_ladder()
	_test_run_numbering_and_first_beat()
	_test_class_priority()
	_test_display_cap_and_queue()
	_test_preempt()
	_test_run_start_after_death()
	_test_time_beat()
	_test_idle_and_motion()
	await _test_persistence()
	_test_save_on_quit()

	Support.remove_file(PATH)
	if _failures.is_empty():
		print("PASS test_narrator")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_narrator")
		quit(1)


func _test_data() -> void:
	var config: NarratorConfig = load(CONFIG_PATH)
	_check(config.beats.size() == 26, "expected 26 beats, got %d" % config.beats.size())
	var tags: Dictionary = {}
	var ids: Dictionary = {}
	var moods: Dictionary = {}
	for m: NarrationMood in config.moods:
		moods[m.id] = true
	for b in config.beats:
		_check(not ids.has(b.id), "duplicate beat id %s" % b.id)
		ids[b.id] = true
		_check(moods.has(b.mood), "beat %s uses unknown mood %s" % [b.id, b.mood])
		for t in b.origin_tags:
			tags[t] = tags.get(t, 0) + 1
	for tag in ["hero", "villain", "alien", "ai", "demonic", "angelic", "none"]:
		_check(tags.get(tag, 0) >= 3, "origin tag %s in fewer than 3 beats" % tag)
	_check(config.moods.size() == 5, "expected 5 sound moods")
	var time_beat: NarrationBeat = null
	for b in config.beats:
		if b.trigger == NarrationBeat.Trigger.TIME:
			time_beat = b
	_check(time_beat != null and time_beat.delay == 60.0, "TIME beat with 60 s delay missing")


func _test_eligibility() -> void:
	var rig := _rig()
	var n: Node = rig["narrator"]
	var came_back: NarrationBeat = _beat(n, "start_came_back")
	_check(not n.call("is_eligible", came_back, 1, 0), "min_run 2 beat must not play in run 1")
	_check(not n.call("is_eligible", came_back, 2, 0), "min_deaths 1 must block with 0 deaths")
	_check(n.call("is_eligible", came_back, 2, 1), "run 2 with 1 death should be eligible")
	_check(not n.call("is_eligible", came_back, 3, 2), "max_run 2 must block run 3")
	var chose: NarrationBeat = _beat(n, "start_chose_return")
	_check(n.call("is_eligible", chose, 7, 6) and n.call("is_eligible", chose, 40, 39), "max_run -1 has no upper bound")
	_check(not n.call("is_eligible", chose, 6, 5), "run 6 is below min_run 7")
	var svc: Node = rig["svc"]
	(svc.get("progress") as PersistentProgress).heard_beats.append("start_came_back")
	_check(not n.call("is_eligible", came_back, 2, 1), "a heard beat is not eligible again")
	_teardown(rig)


func _test_ladder() -> void:
	var rig := _rig()
	var n: Node = rig["narrator"]
	n.set("run_count", 5)
	n.set("death_count", 4)
	var order: PackedStringArray = []
	for i in 3:
		var pick: NarrationBeat = n.call("pick_for_event", &"died_spikes")
		order.append(pick.id if pick != null else "none")
		if pick != null:
			(n.get("_heard") as Dictionary)[pick.id] = true
	_check(order == PackedStringArray(["death_spikes_down", "death_spikes_willing", "death_spikes_watch"]), "ladder out of order: %s" % [order])
	_check(n.call("pick_for_event", &"died_spikes") == null, "ladder exhausted should give nothing")
	# A late first encounter still gets the lowest rung first.
	var cleared: Dictionary[String, bool] = {}
	n.set("_heard", cleared)
	_check((n.call("pick_for_event", &"spikes_revealed") as NarrationBeat).id == "spikes_teeth", "late first encounter must start with the cryptic rung")
	_teardown(rig)


func _test_run_numbering_and_first_beat() -> void:
	var rig := _rig()
	var n: Node = rig["narrator"]
	_start_run(rig)
	_check(n.get("run_count") == 1 and n.get("death_count") == 0, "first run should be run_count 1, got %d" % n.get("run_count"))
	_wait(n, STEP)
	_check(_started == PackedStringArray(["wake_first"]), "run 1 should open with wake_first, got %s" % [_started])
	_check((rig["svc"].get("progress") as PersistentProgress).heard_beats.has("wake_first"), "heard beat should reach SaveService on display")
	_teardown(rig)


func _test_class_priority() -> void:
	var rig := _rig()
	var n: Node = rig["narrator"]
	_start_run(rig)
	_bus.emit_signal("narration_event", &"wall_revealed")
	_bus.emit_signal("narration_event", &"spikes_revealed")
	_bus.emit_signal("narration_event", &"idle")
	_wait(n, STEP)
	_check(_started == PackedStringArray(["spikes_teeth"]), "highest class should win simultaneous triggers, got %s" % [_started])
	_check(not (rig["svc"].get("progress") as PersistentProgress).heard_beats.has("wake_first"), "a beat that lost the frame must stay unheard")
	_check(n.call("pick_for_event", &"run_started") != null, "dropped run_started beat should stay eligible")
	_teardown(rig)


func _test_display_cap_and_queue() -> void:
	var rig := _rig()
	var n: Node = rig["narrator"]
	var config: NarratorConfig = rig["config"]
	_start_run(rig)
	_wait(n, STEP)
	_check(_started == PackedStringArray(["wake_first"]), "setup: wake_first first")
	_bus.emit_signal("narration_event", &"wall_revealed")
	_wait(n, STEP)
	_check((n.get("queued") as NarrationBeat) != null and (n.get("queued") as NarrationBeat).id == "wall_edges", "second beat should queue")
	_check(_started.size() == 1, "only one beat on screen")
	_bus.emit_signal("narration_event", &"item_revealed")
	_wait(n, STEP)
	_check((n.get("queued") as NarrationBeat).id == "wall_edges", "equal class must not replace the queued beat")
	_bus.emit_signal("narration_event", &"corruption_entered")
	_wait(n, STEP)
	_check((n.get("queued") as NarrationBeat).id == "corrupt_knows", "higher class should replace the queued beat")
	# TTL: the beat waits longer than queue_ttl_seconds behind the current one, so it is dropped.
	_wait(n, config.queue_ttl_seconds + 0.5)
	_check(n.get("queued") == null, "queued beat should be dropped after the TTL")
	_check(_started == PackedStringArray(["wake_first"]), "dropped beat must not play, got %s" % [_started])
	_check(not (rig["svc"].get("progress") as PersistentProgress).heard_beats.has("corrupt_knows"), "dropped beat stays unheard")
	_check(n.call("pick_for_event", &"corruption_entered") != null, "dropped beat stays eligible")
	_teardown(rig)

	# Queued beat plays after the gap when the TTL allows it; never two on screen.
	rig = _rig(func(c: NarratorConfig) -> void:
		c.morph_in_seconds = 0.2
		c.beat_hold_seconds = 0.4
		c.morph_out_seconds = 0.2
		c.beat_gap_seconds = 0.5
		c.queue_ttl_seconds = 5.0)
	n = rig["narrator"]
	_start_run(rig)
	_wait(n, STEP)
	_bus.emit_signal("narration_event", &"wall_revealed")
	_wait(n, STEP)
	var box: Dictionary = {"overlap": false, "showing": 1}
	n.connect("beat_started", func(_b: NarrationBeat) -> void:
		box["showing"] += 1
		box["overlap"] = box["overlap"] or box["showing"] > 1)
	n.connect("beat_dissolving", func(_f: bool) -> void: box["showing"] -= 1)
	_wait(n, 3.0)
	_check(_started == PackedStringArray(["wake_first", "wall_edges"]), "queued beat should play after the gap, got %s" % [_started])
	_check(not box["overlap"], "two beats were on screen at once")
	_teardown(rig)


func _test_preempt() -> void:
	var rig := _rig()
	var n: Node = rig["narrator"]
	var config: NarratorConfig = rig["config"]
	_start_run(rig)
	_wait(n, STEP)
	_bus.emit_signal("narration_event", &"wall_revealed")
	_wait(n, STEP)
	_check(n.get("queued") != null, "setup: a beat is queued")
	_bus.emit_signal("run_ended", &"spikes")
	_wait(n, STEP)
	_check(_fast_dissolves == 1, "death beat should dissolve the current beat at once")
	_check(n.get("queued") == null, "death clears the queue")
	_check(_started == PackedStringArray(["wake_first"]), "death beat waits for the quick dissolve")
	_wait(n, config.preempt_dissolve_seconds + STEP)
	_check(_started == PackedStringArray(["wake_first", "death_spikes_down"]), "death beat should preempt, got %s" % [_started])
	# Death during the gap starts immediately.
	_wait(n, config.morph_in_seconds + config.beat_hold_seconds + config.morph_out_seconds + 0.5)
	_check(_state(n) == Narrator_State.GAP, "setup: in the gap after the death beat")
	_bus.emit_signal("run_started", 1)
	_bus.emit_signal("run_ended", &"corruption")
	_wait(n, STEP)
	_check(_started[_started.size() - 1] == "death_corrupt_scatter", "death beat should play even during the gap, got %s" % [_started])
	_teardown(rig)


## Mirror of Narrator.State (the test cannot name the class: it references the SignalBus autoload).
class Narrator_State:
	const FREE := 0
	const SHOWING := 1
	const DISSOLVING := 2
	const GAP := 3
	const PREEMPTING := 4


func _test_time_beat() -> void:
	var rig := _rig()
	var n: Node = rig["narrator"]
	var progress: PersistentProgress = rig["svc"].get("progress")
	progress.run_count = 2
	progress.death_count = 2
	_start_run(rig)
	_check(n.get("run_count") == 3, "setup: run 3")
	_wait(n, 59.0)
	_check(not _started.has("time_counting_signals"), "TIME beat must not fire before its delay")
	_wait(n, 2.0)
	_check(_started.has("time_counting_signals"), "TIME beat should fire after 60 s, got %s" % [_started])
	_teardown(rig)

	rig = _rig()
	n = rig["narrator"]
	progress = rig["svc"].get("progress")
	progress.run_count = 2
	progress.death_count = 2
	_start_run(rig)
	_wait(n, 20.0)
	_bus.emit_signal("run_ended", &"unknown")
	_wait(n, 80.0)
	_check(not _started.has("time_counting_signals"), "TIME beat must be skipped after the run ended")
	_teardown(rig)


func _test_idle_and_motion() -> void:
	var rig := _rig()
	var n: Node = rig["narrator"]
	var config: NarratorConfig = rig["config"]
	_start_run(rig)
	_wait(n, STEP)
	_bus.emit_signal("player_motion_changed", true)
	_wait(n, config.idle_seconds + 2.0)
	_check(not _started.has("idle_still"), "idle must not fire while moving")
	_bus.emit_signal("player_motion_changed", false)
	_wait(n, config.idle_seconds - 1.0)
	_check(not _started.has("idle_still"), "idle must wait idle_seconds of stillness")
	_wait(n, 2.0 + config.beat_gap_seconds + config.beat_hold_seconds * 2.0)
	_check(_started.has("idle_still"), "idle beat should fire after idle_seconds of stillness, got %s" % [_started])
	_teardown(rig)

	# erosion_high fires once when the fraction crosses the configured threshold.
	rig = _rig()
	n = rig["narrator"]
	config = rig["config"]
	_start_run(rig)
	_wait(n, STEP)
	_bus.emit_signal("player_motion_changed", true)
	_wait(n, config.morph_in_seconds + config.beat_hold_seconds + config.morph_out_seconds + config.beat_gap_seconds + 0.5)
	_bus.emit_signal("erosion_changed", config.erosion_high_threshold - 0.1, Color.WHITE)
	_wait(n, STEP)
	_check(not _started.has("erosion_again"), "below the threshold nothing fires")
	_bus.emit_signal("erosion_changed", config.erosion_high_threshold, Color.WHITE)
	_wait(n, STEP)
	_check(_started.has("erosion_again"), "erosion_high should fire at the threshold")
	_teardown(rig)


func _test_persistence() -> void:
	var rig := _rig()
	var n: Node = rig["narrator"]
	_start_run(rig)
	_wait(n, STEP)
	_bus.emit_signal("run_ended", &"unknown")
	_check(FileAccess.file_exists(PATH), "run end should have saved progress")
	_teardown(rig)

	# A new launch: heard beats come from disk and the next run starts with its own beat.
	rig = _rig(Callable(), false)
	n = rig["narrator"]
	var progress: PersistentProgress = rig["svc"].get("progress")
	_check(progress.heard_beats.has("wake_first"), "heard beat should be persisted")
	_start_run(rig)
	_check(n.get("run_count") == 2 and n.get("death_count") == 1, "run 2 after one death, got %d/%d" % [n.get("run_count"), n.get("death_count")])
	_wait(n, STEP)
	_check(_started == PackedStringArray(["start_came_back"]), "run 2 should open with start_came_back, got %s" % [_started])
	_check(not _started.has("wake_first"), "a heard beat must not repeat")
	_teardown(rig)
	Support.remove_file(PATH)
	await process_frame


func _test_save_on_quit() -> void:
	Support.remove_file(PATH)
	var cfg := SaveConfig.new()
	cfg.save_path = PATH
	var svc: Node = load("res://scripts/core/save_service.gd").new()
	svc.set("config", cfg)
	root.add_child(svc)
	svc.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_check(not FileAccess.file_exists(PATH), "an unchanged save must not be rewritten on quit")
	_bus.emit_signal("run_started", 0)
	_bus.emit_signal("beat_heard", "wake_first")
	_bus.emit_signal("cells_revealed", &"m", PackedVector2Array([Vector2(3, 4)]))
	_check(not FileAccess.file_exists(PATH), "setup: nothing saved yet mid-run")
	svc.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_check(FileAccess.file_exists(PATH), "close request should save mid-run progress")
	svc.free()
	var reloaded: Node = load("res://scripts/core/save_service.gd").new()
	reloaded.set("config", cfg)
	root.add_child(reloaded)
	var progress: PersistentProgress = reloaded.get("progress")
	_check(progress.heard_beats.has("wake_first") and progress.run_count == 1, "mid-run heard beat and run count should survive")
	_check((progress.revealed_cells.get(&"m", PackedVector2Array()) as PackedVector2Array).size() == 1, "mid-run reveals should survive")
	reloaded.free()

	# Leaving the tree (get_tree().quit()) saves as well.
	Support.remove_file(PATH)
	var leaving: Node = load("res://scripts/core/save_service.gd").new()
	leaving.set("config", cfg)
	root.add_child(leaving)
	_bus.emit_signal("beat_heard", "move_first")
	_check(not FileAccess.file_exists(PATH), "setup: not saved yet")
	root.remove_child(leaving)
	_check(FileAccess.file_exists(PATH), "leaving the tree should save pending progress")
	leaving.free()


## Death beat -> restart -> the run-2 start beat still plays with the DEFAULT queue TTL; a new run
## cuts the gap; a displaced start beat re-queues instead of dropping.
func _test_run_start_after_death() -> void:
	var rig := _rig()
	var n: Node = rig["narrator"]
	var config: NarratorConfig = rig["config"]
	_check(config.queue_ttl_seconds == 5.0, "setup: default TTL expected")
	_start_run(rig)
	_wait(n, STEP)
	_bus.emit_signal("run_ended", &"spikes")
	_wait(n, config.preempt_dissolve_seconds + STEP)
	_check(_started == PackedStringArray(["wake_first", "death_spikes_down"]), "setup: death beat showing, got %s" % [_started])
	_wait(n, 1.5)
	_bus.emit_signal("run_started", 1)
	_wait(n, 20.0)
	_check(_started.has("start_came_back"), "run-2 start beat must survive the default TTL, got %s" % [_started])
	_teardown(rig)

	# A new run cuts the post-beat gap.
	rig = _rig()
	n = rig["narrator"]
	config = rig["config"]
	_start_run(rig)
	_wait(n, config.morph_in_seconds + config.beat_hold_seconds + config.morph_out_seconds + 0.5)
	_check(_state(n) == Narrator_State.GAP, "setup: in the gap")
	_bus.emit_signal("run_ended", &"unknown")
	_bus.emit_signal("run_started", 1)
	_wait(n, STEP * 2.0)
	_check(_started == PackedStringArray(["wake_first", "start_came_back"]), "new run should cut the gap, got %s" % [_started])
	_teardown(rig)

	# A start beat displaced from the queue by a higher class is parked and plays afterwards.
	rig = _rig(func(c: NarratorConfig) -> void: c.queue_ttl_seconds = 30.0)
	n = rig["narrator"]
	config = rig["config"]
	_start_run(rig)
	_wait(n, STEP)
	_bus.emit_signal("run_ended", &"unknown")
	_bus.emit_signal("run_started", 1)
	_wait(n, STEP)
	_check(_state(n) == Narrator_State.SHOWING and _started.size() == 1, "setup: wake_first still on screen")
	_check(_started == PackedStringArray(["wake_first"]), "setup: wake_first first")
	_wait(n, STEP)
	_check((n.get("queued") as NarrationBeat) != null and (n.get("queued") as NarrationBeat).id == "start_came_back", "start beat should queue")
	_bus.emit_signal("narration_event", &"corruption_entered")
	_wait(n, STEP)
	_check((n.get("queued") as NarrationBeat).id == "corrupt_knows", "higher class replaces the queued start beat")
	_wait(n, 40.0)
	_check(_started == PackedStringArray(["wake_first", "corrupt_knows", "start_came_back"]), "displaced start beat should re-queue, got %s" % [_started])
	_teardown(rig)
