extends SceneTree
## Headless test of the narrator (task-014): eligibility, ladder order, class priority, display cap
## with queue / TTL / replacement, death preempt, TIME beats, persisted heard beats, save on quit.
## Origin integration (task-042/044): the 14 origin lines match docs/narration_origin.md, claims arm trials,
## struck / recanted nature -> broken / recant line, doubt flag, floor tie-break, claim_ai_one on a form switch.
## Time is driven by calling Narrator.advance() so the test is deterministic. Only temporary save
## paths are used; they are removed at the end.
## Usage: godot --headless --path . -s tools/test_narrator.gd

const Support := preload("res://tools/test_support.gd")
const PATH := "user://test_progress_narrator.tres"
const CONFIG_PATH := "res://resources/narration/narrator_config.tres"
const ORIGIN_CONFIG_PATH := "res://resources/config/origin_config.tres"
const ORIGIN_DOC := "res://docs/narration_origin.md"
const STEP := 0.1
const M1_BEATS := 26
const ORIGIN_RUN := 5
const ORIGIN_DEATHS := 4

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
func _rig(tweak: Callable = Callable(), fresh: bool = true, with_ledger: bool = false) -> Dictionary:
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
	var ledger: Node
	if with_ledger:
		ledger = load("res://scripts/origin/origin_ledger.gd").new()
		ledger.set("config", (load(ORIGIN_CONFIG_PATH) as OriginConfig).duplicate())
		ledger.set("save_service", svc)
		root.add_child(ledger)
	var narrator: Node = load("res://scripts/narrator/narrator.gd").new()
	narrator.set("config", config)
	narrator.set("save_service", svc)
	if ledger != null:
		narrator.set("ledger", ledger)
	root.add_child(narrator)
	_started = PackedStringArray()
	_fast_dissolves = 0
	narrator.connect("beat_started", func(b: NarrationBeat) -> void: _started.append(b.id))
	narrator.connect("beat_dissolving", func(fast: bool) -> void: _fast_dissolves += int(fast))
	return {"svc": svc, "narrator": narrator, "config": config, "ledger": ledger}


func _teardown(rig: Dictionary) -> void:
	(rig["narrator"] as Node).free()
	if rig["ledger"] != null:
		(rig["ledger"] as Node).free()
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
	_test_overlay()
	_test_origin_data()
	_test_origin_claims()
	_test_origin_reactions()
	_test_origin_doubt()
	_test_origin_overlay()
	_test_floor_tie_break()
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
	# 49 = 26 M1 + 3 sprint layers + 6 dirt (task-070: 1 WALL_EATEN world line + 5 WALLS_DEVOURED variants) + 14 origin.
	_check(config.beats.size() == 49, "expected 49 beats (26 M1 + 3 sprint layers + 6 dirt + 14 origin), got %d" % config.beats.size())
	var supports: Dictionary = {}
	var contradicts: Dictionary = {}
	var neutral: int = 0
	var ids: Dictionary = {}
	var moods: Dictionary = {}
	for m: NarrationMood in config.moods:
		moods[m.id] = true
	for b in config.beats:
		_check(not ids.has(b.id), "duplicate beat id %s" % b.id)
		ids[b.id] = true
		_check(moods.has(b.mood), "beat %s uses unknown mood %s" % [b.id, b.mood])
		if b.order < M1_BEATS:
			_check(b.role == NarrationBeat.Role.STORY, "beat %s: the M1 table has only STORY beats" % b.id)
		neutral += int(b.supports.is_empty() and b.contradicts.is_empty())
		for t in b.supports:
			supports[t] = supports.get(t, 0) + 1
			_check(not b.contradicts.has(t), "beat %s lists %s in supports and contradicts" % [b.id, t])
		for t in b.contradicts:
			contradicts[t] = contradicts.get(t, 0) + 1
	for tag in ["hero", "villain", "alien", "ai", "demonic", "angelic"]:
		_check(supports.get(tag, 0) >= 3, "hypothesis %s supported by fewer than 3 beats" % tag)
	_check(neutral >= 3, "fewer than 3 neutral beats")
	# Stance table of docs/game_design.md (Origin Contradiction, section 5).
	for tag in ["ai", "demonic", "alien", "angelic"]:
		# Story beats (docs/narration_origin.md balance table) plus one claim and one recant line per nature.
		_check(supports.get(tag, 0) == {"ai": 8, "demonic": 7, "alien": 7, "angelic": 7}[tag], "support count of %s" % tag)
	var expected_contra: Dictionary = {
		"start_came_back": ["demonic"], "corrupt_after_war": ["demonic"], "erosion_true_name": ["ai"],
		"death_spikes_willing": ["villain"], "idle_burned": ["hero"],
		"item_carried_down": ["alien"], "time_hull_burn": ["angelic"],
		"broken_demonic": ["demonic"], "broken_ai": ["ai"], "broken_angelic": ["angelic"], "broken_alien": ["alien"],
	}
	for b in config.beats:
		_check(Array(b.contradicts) == expected_contra.get(b.id, []), "beat %s contradicts %s" % [b.id, b.contradicts])
	for id in ["start_hero_lied", "wall_keep_them_out"]:
		var both: NarrationBeat = _beat_by_id(config, id)
		_check(both.supports.has("hero") and both.supports.has("villain"), "%s supports both deeds" % id)
	_test_lint(config)
	_check(config.moods.size() == 5, "expected 5 sound moods")
	var delays: Array = []
	for b in config.beats:
		if b.trigger == NarrationBeat.Trigger.TIME:
			delays.append(b.delay)
	_check(delays == [60.0, 90.0], "TIME beats with 60 s and 90 s delay expected, got %s" % [delays])


## NarrationLint (task-040): the real table passes; synthetic tables fail for each rule.
func _test_lint(config: NarratorConfig) -> void:
	var origin: OriginConfig = load("res://resources/config/origin_config.tres")
	var natures: PackedStringArray = origin.nature_ids()
	var deeds: PackedStringArray = origin.deed_ids()
	var strict_real: Dictionary = NarrationLint.lint(config.beats, natures, deeds, true)
	_check((strict_real["errors"] as PackedStringArray).is_empty() and (strict_real["warnings"] as PackedStringArray).is_empty(), "the full table passes the strict lint: %s" % [strict_real])
	var m1_only: Array = config.beats.filter(func(b: NarrationBeat) -> bool: return b.order < M1_BEATS)
	var real: Dictionary = NarrationLint.lint(m1_only, natures, deeds, false)
	_check((real["errors"] as PackedStringArray).is_empty(), "the M1 table passes the lint: %s" % [real["errors"]])
	_check((real["warnings"] as PackedStringArray).size() == 2, "without the origin beats alien and angelic lack a contradicting beat, got %s" % [real["warnings"]])
	var strict: Dictionary = NarrationLint.lint(m1_only, natures, deeds, true)
	_check((strict["errors"] as PackedStringArray).size() == 2 and (strict["warnings"] as PackedStringArray).is_empty(), "strict mode turns the missing contradictions into errors")
	# Role rules.
	var bad_claim: Array = _full_table_with(_role_beat("c", NarrationBeat.Role.CLAIM, [], [], &"", &""))
	_check((NarrationLint.lint(bad_claim, natures, deeds, false)["errors"] as PackedStringArray).size() == 1, "a claim without a nature is an error")
	var bad_broken: Array = _full_table_with(_role_beat("b", NarrationBeat.Role.BROKEN, [], ["ai"], NarrationEvents.ORIGIN_RECANTED, &"ai"))
	_check((NarrationLint.lint(bad_broken, natures, deeds, false)["errors"] as PackedStringArray).size() == 1, "a broken beat on the wrong event is an error")
	var bad_recant: Array = _full_table_with(_role_beat("r", NarrationBeat.Role.RECANT, [], [], NarrationEvents.ORIGIN_RECANTED, &"ai"))
	_check((NarrationLint.lint(bad_recant, natures, deeds, false)["errors"] as PackedStringArray).size() == 1, "a recant beat that does not support its nature is an error")

	var full: Array = []
	for n in natures:
		full.append(_lint_beat("s_" + n, [n], []))
		full.append(_lint_beat("c_" + n, [], [n]))
	_check((NarrationLint.lint(full, natures, deeds, true)["errors"] as PackedStringArray).is_empty(), "a table with every nature supported and contradicted passes strict")
	var both: Array = full.duplicate()
	both.append(_lint_beat("both", ["ai"], ["ai"]))
	_check((NarrationLint.lint(both, natures, deeds, false)["errors"] as PackedStringArray).size() == 1, "a hypothesis in both supports and contradicts is an error")
	var unsupported: Array = full.filter(func(b: NarrationBeat) -> bool: return b.id != "s_alien")
	_check((NarrationLint.lint(unsupported, natures, deeds, false)["errors"] as PackedStringArray).size() == 1, "a nature without a supporting beat is an error")
	var unknown: Array = full.duplicate()
	unknown.append(_lint_beat("typo", ["alein"], []))
	_check((NarrationLint.lint(unknown, natures, deeds, false)["errors"] as PackedStringArray).size() == 1, "an unknown hypothesis id is an error")


func _full_table_with(extra: NarrationBeat) -> Array:
	var table: Array = []
	for n in (load(ORIGIN_CONFIG_PATH) as OriginConfig).nature_ids():
		table.append(_lint_beat("s_" + n, [n], []))
		table.append(_lint_beat("c_" + n, [], [n]))
	table.append(extra)
	return table


func _role_beat(id: String, role: NarrationBeat.Role, supports: Array, contradicts: Array, event: StringName, param: StringName) -> NarrationBeat:
	var beat: NarrationBeat = _lint_beat(id, supports, contradicts)
	beat.role = role
	beat.event = event
	beat.event_param = param
	return beat


func _lint_beat(id: String, supports: Array, contradicts: Array) -> NarrationBeat:
	var beat := NarrationBeat.new()
	beat.id = id
	beat.supports = PackedStringArray(supports)
	beat.contradicts = PackedStringArray(contradicts)
	return beat


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
		var pick: NarrationBeat = n.call("pick_for_event", &"DEATH_BY_SPIKES")
		order.append(pick.id if pick != null else "none")
		if pick != null:
			(n.get("_heard") as Dictionary)[pick.id] = true
	_check(order == PackedStringArray(["death_spikes_down", "death_spikes_willing", "death_spikes_watch"]), "ladder out of order: %s" % [order])
	_check(n.call("pick_for_event", &"DEATH_BY_SPIKES") == null, "ladder exhausted should give nothing")
	# A late first encounter still gets the lowest rung first.
	var cleared: Dictionary[String, bool] = {}
	n.set("_heard", cleared)
	_check((n.call("pick_for_event", &"SPIKES_REVEALED") as NarrationBeat).id == "spikes_teeth", "late first encounter must start with the cryptic rung")
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
	_bus.emit_signal("narration_event", &"WALL_REVEALED")
	_bus.emit_signal("narration_event", &"SPIKES_REVEALED")
	_bus.emit_signal("narration_event", &"IDLE_FOR_SHORT")
	_wait(n, STEP)
	_check(_started == PackedStringArray(["spikes_teeth"]), "highest class should win simultaneous triggers, got %s" % [_started])
	_check(not (rig["svc"].get("progress") as PersistentProgress).heard_beats.has("wake_first"), "a beat that lost the frame must stay unheard")
	_check(n.call("pick_for_event", &"RUN_STARTED") != null, "dropped run_started beat should stay eligible")
	_teardown(rig)


func _test_display_cap_and_queue() -> void:
	var rig := _rig()
	var n: Node = rig["narrator"]
	var config: NarratorConfig = rig["config"]
	_start_run(rig)
	_wait(n, STEP)
	_check(_started == PackedStringArray(["wake_first"]), "setup: wake_first first")
	_bus.emit_signal("narration_event", &"WALL_REVEALED")
	_wait(n, STEP)
	_check((n.get("queued") as NarrationBeat) != null and (n.get("queued") as NarrationBeat).id == "wall_edges", "second beat should queue")
	_check(_started.size() == 1, "only one beat on screen")
	_bus.emit_signal("narration_event", &"ITEM_REVEALED")
	_wait(n, STEP)
	_check((n.get("queued") as NarrationBeat).id == "wall_edges", "equal class must not replace the queued beat")
	_bus.emit_signal("narration_event", &"CORRUPTION_ENTERED")
	_wait(n, STEP)
	_check((n.get("queued") as NarrationBeat).id == "corrupt_knows", "higher class should replace the queued beat")
	# TTL: the beat waits longer than queue_ttl_seconds behind the current one, so it is dropped.
	_wait(n, config.queue_ttl_seconds + 0.5)
	_check(n.get("queued") == null, "queued beat should be dropped after the TTL")
	_check(_started == PackedStringArray(["wake_first"]), "dropped beat must not play, got %s" % [_started])
	_check(not (rig["svc"].get("progress") as PersistentProgress).heard_beats.has("corrupt_knows"), "dropped beat stays unheard")
	_check(n.call("pick_for_event", &"CORRUPTION_ENTERED") != null, "dropped beat stays eligible")
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
	_bus.emit_signal("narration_event", &"WALL_REVEALED")
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
	_bus.emit_signal("narration_event", &"WALL_REVEALED")
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
	_bus.emit_signal("narration_event", &"CORRUPTION_ENTERED")
	_wait(n, STEP)
	_check((n.get("queued") as NarrationBeat).id == "corrupt_knows", "higher class replaces the queued start beat")
	_wait(n, 40.0)
	_check(_started == PackedStringArray(["wake_first", "corrupt_knows", "start_came_back"]), "displaced start beat should re-queue, got %s" % [_started])
	_teardown(rig)


## The overlay presentation (task-034): calm letter assembly/dispersal, no character swapping, text kept clear of the
## player (centre of the screen), every beat mood has a glow tint.
func _test_overlay() -> void:
	var config: NarratorConfig = (load(CONFIG_PATH) as NarratorConfig).duplicate()
	for beat: NarrationBeat in config.beats:
		_check(config.mood_glow_colors.has(beat.mood), "beat %s mood %s has no glow tint" % [beat.id, beat.mood])
	root.size = Vector2i(1366, 768)
	var overlay: Node = load("res://scripts/narrator/narration_overlay.gd").new()
	overlay.set("config", config)
	root.add_child(overlay)
	var beat: NarrationBeat = _beat_by_id(config, "wake_first")
	_check(not overlay.call("is_showing"), "overlay idle before a beat")
	overlay.call("show_beat", beat)
	_check(overlay.call("is_showing"), "overlay shows the beat")
	var chars: PackedStringArray = overlay.get("_chars")
	_check("".join(chars) == beat.text.replace(" ", ""), "letters are exactly the beat text (no swapped characters), got %s" % ["".join(chars)])
	var rest: PackedVector2Array = overlay.get("_rest")
	var view: Vector2 = root.get_visible_rect().size
	for p: Vector2 in rest:
		_check(p.y > view.y * 0.6 and p.y < view.y and p.x > 0.0 and p.x < view.x, "letter at rest stays in the lower third and on screen: %s" % [p])
	overlay.call("advance", config.morph_in_seconds * 0.3)
	var pos: PackedVector2Array = overlay.get("_pos")
	var moved: int = 0
	for i in pos.size():
		if pos[i].distance_to(rest[i]) > 1.0:
			moved += 1
	_check(moved > 0, "letters are in flight mid-assembly")
	overlay.call("advance", config.morph_in_seconds)
	_check(overlay.get("phase") == 2, "assembled line rests (HOLD)")
	_check(not overlay.is_processing(), "a resting line costs no per-frame processing")
	pos = overlay.get("_pos")
	for i in pos.size():
		_check(pos[i].is_equal_approx(rest[i]), "rested letter %d on its place" % i)
	overlay.call("dissolve", true)
	_check(overlay.get("phase") == 3, "dissolving")
	overlay.call("advance", config.preempt_dissolve_seconds + 0.05)
	_check(not overlay.call("is_showing"), "fast dissolve clears the line")
	overlay.call("show_beat", beat)
	overlay.call("dissolve", false)
	overlay.call("advance", config.morph_out_seconds + 0.05)
	_check(not overlay.call("is_showing"), "normal dissolve clears the line")
	overlay.free()


# --- Origin integration (task-042 / task-044) ------------------------------------------------------------------------

## The 14 table rows of docs/narration_origin.md as dictionaries (column names as in the doc).
func _doc_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for line in FileAccess.get_file_as_string(ORIGIN_DOC).split("\n"):
		if not line.begins_with("| `"):
			continue
		var c: PackedStringArray = []
		for cell in line.strip_edges().trim_prefix("|").trim_suffix("|").split("|"):
			c.append(cell.strip_edges())
		if c.size() != 12:
			continue
		rows.append({
			"id": c[0].trim_prefix("`").trim_suffix("`"), "text": c[1], "role": c[2], "trigger": c[3], "param": c[4],
			"min_run": c[5], "max_run": c[6], "min_deaths": c[7], "once": c[8], "mood": c[9], "supports": c[10], "contradicts": c[11],
		})
	return rows


func _ids_of(cell: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if cell == "-":
		return out
	for id in cell.split(","):
		out.append(id.strip_edges())
	return out


## The origin lines in the beat table equal the approved doc, field by field (text copied exactly).
func _test_origin_data() -> void:
	var config: NarratorConfig = load(CONFIG_PATH)
	var rows: Array[Dictionary] = _doc_rows()
	_check(rows.size() == 14, "the doc lists 14 origin lines, parsed %d" % rows.size())
	var roles: Dictionary = {}
	for row in rows:
		var b: NarrationBeat = _beat_by_id(config, row["id"])
		if b == null:
			_check(false, "origin beat %s missing from the table" % row["id"])
			continue
		_check(b.text == row["text"], "text of %s differs from docs/narration_origin.md: '%s'" % [row["id"], b.text])
		_check(NarrationBeat.Role.keys()[b.role] == row["role"], "role of %s" % row["id"])
		roles[row["role"]] = int(roles.get(row["role"], 0)) + 1
		var trigger: String = row["trigger"]
		if trigger.begins_with("TIME"):
			_check(b.trigger == NarrationBeat.Trigger.TIME and b.delay == float(trigger.split(" ")[1]), "TIME trigger of %s" % row["id"])
		else:
			_check(b.trigger == NarrationBeat.Trigger.EVENT and String(b.event) == trigger.split("`")[1], "event of %s" % row["id"])
		_check(String(b.event_param) == ("" if row["param"] == "-" else row["param"]), "event_param of %s" % row["id"])
		_check(b.min_run == int(row["min_run"]) and b.min_deaths == int(row["min_deaths"]), "gates of %s" % row["id"])
		_check(b.max_run == (-1 if row["max_run"] == "none" else int(row["max_run"])), "max_run of %s" % row["id"])
		_check(b.once == (row["once"] == "true"), "once of %s" % row["id"])
		_check(String(b.mood) == row["mood"], "mood of %s" % row["id"])
		_check(b.supports == _ids_of(row["supports"]) and b.contradicts == _ids_of(row["contradicts"]), "stances of %s" % row["id"])
	_check(roles == {"CLAIM": 4, "BROKEN": 4, "RECANT": 4, "STORY": 2}, "4 claims, 4 broken, 4 recant, 2 story lines, got %s" % [roles])
	var claim_ai: NarrationBeat = _beat_by_id(config, "claim_ai_one")
	_check(claim_ai.event == NarrationEvents.ENTITY_FORM_CHANGED, "claim_ai_one triggers on the form switch (user decision)")
	for id in ["broken_demonic", "broken_ai", "broken_angelic", "broken_alien"]:
		_check(_beat_by_id(config, id).event == NarrationEvents.ORIGIN_STRUCK and not _beat_by_id(config, id).once, "%s answers origin_struck and may repeat" % id)
	for id in ["recant_demonic", "recant_ai", "recant_angelic", "recant_alien"]:
		_check(_beat_by_id(config, id).event == NarrationEvents.ORIGIN_RECANTED and not _beat_by_id(config, id).once, "%s answers origin_recanted and may repeat" % id)
	var origin: OriginConfig = load(ORIGIN_CONFIG_PATH)
	_check(not origin.find(&"alien").trial.dormant and not origin.find(&"ai").trial.dormant, "no trial is dormant (alien: task-045)")


## A rig with ledger where every ordinary beat (except `keep`) is already heard, at run 5 / 4 deaths, a moving player
## (no automatic idle event) and the run started. Only origin beats and the kept ones can play.
func _origin_rig(keep: PackedStringArray = PackedStringArray(), tweak: Callable = Callable()) -> Dictionary:
	var rig := _rig(tweak, true, true)
	var progress: PersistentProgress = rig["svc"].get("progress")
	progress.run_count = ORIGIN_RUN
	progress.death_count = ORIGIN_DEATHS
	for b: NarrationBeat in (rig["config"] as NarratorConfig).beats:
		var origin_line: bool = b.role != NarrationBeat.Role.STORY
		if not origin_line and not keep.has(b.id):
			progress.heard_beats.append(b.id)
	_start_run(rig)
	_bus.emit_signal("player_motion_changed", true)
	_wait(rig["narrator"], STEP)
	_started = PackedStringArray()
	return rig


func _test_origin_claims() -> void:
	var rig := _origin_rig()
	var n: Node = rig["narrator"]
	var ledger: Node = rig["ledger"]
	var heard: Array = []
	var on_claim := func(id: StringName) -> void: heard.append(id)
	_bus.connect("origin_claim_heard", on_claim)
	_check(not ledger.call("is_armed", &"demonic"), "setup: nothing armed")

	_bus.emit_signal("narration_event", &"CORRUPTION_ENTERED")
	_wait(n, STEP)
	_check(_started == PackedStringArray(["claim_demonic_name"]), "the demonic claim plays on corruption_entered, got %s" % [_started])
	_check(heard == [&"demonic"], "hearing the claim emits origin_claim_heard(demonic), got %s" % [heard])
	_check(ledger.call("is_armed", &"demonic") and not ledger.call("is_armed", &"ai"), "the claim arms its own trial only")
	_check(not (rig["svc"].get("progress") as PersistentProgress).armed_trials.has("ai"), "armed state is saved by the ledger")

	_wait(n, 12.0)
	_bus.emit_signal("narration_event", &"IDLE_FOR_SHORT")
	_wait(n, STEP)
	_check(_started == PackedStringArray(["claim_demonic_name", "claim_angelic_dark"]), "the angelic claim plays on idle, got %s" % [_started])
	_check(ledger.call("is_armed", &"angelic"), "angelic armed by its claim")

	# The alien claim is no longer dormant (task-045): item_revealed plays it and arms the trial.
	_check(ledger.call("is_claimable", &"alien"), "alien is claimable")
	_wait(n, 12.0)
	_bus.emit_signal("narration_event", &"ITEM_REVEALED")
	_wait(n, STEP)
	_check(_started.size() == 3 and _started[2] == "claim_alien_weight" and ledger.call("is_armed", &"alien"), "the alien claim plays on item_revealed, got %s" % [_started])

	# claim_ai_one: only a chosen form switch (animate = true) fires it.
	_bus.emit_signal("entity_form_changed", &"single", false)
	_wait(n, STEP)
	_check(_started.size() == 3, "the run-start restore of the form is not a switch")
	_wait(n, 12.0)
	_bus.emit_signal("entity_form_changed", &"single", true)
	_wait(n, STEP)
	_check(_started.size() == 4 and _started[3] == "claim_ai_one", "claim_ai_one fires on the form switch, got %s" % [_started])
	_check(heard == [&"demonic", &"angelic", &"alien", &"ai"] and ledger.call("is_armed", &"ai"), "the ai claim arms the ai trial, got %s" % [heard])
	_bus.disconnect("origin_claim_heard", on_claim)

	# Claims are once-only; an armed or struck nature gets no claim.
	_check(not n.call("is_eligible", _beat(n, "claim_demonic_name"), ORIGIN_RUN, ORIGIN_DEATHS), "a heard claim never replays")
	_teardown(rig)

	rig = _origin_rig()
	n = rig["narrator"]
	ledger = rig["ledger"]
	_check(n.call("is_eligible", _beat(n, "claim_demonic_name"), ORIGIN_RUN, ORIGIN_DEATHS), "setup: the claim is eligible")
	_check(not n.call("is_eligible", _beat(n, "claim_demonic_name"), ORIGIN_RUN, ORIGIN_DEATHS - 2), "claims wait for min_deaths 3")
	ledger.call("arm", &"demonic")
	_check(not n.call("is_eligible", _beat(n, "claim_demonic_name"), ORIGIN_RUN, ORIGIN_DEATHS), "an armed nature gets no claim")
	ledger.call("strike", &"angelic", ORIGIN_RUN)
	_check(not n.call("is_eligible", _beat(n, "claim_angelic_dark"), ORIGIN_RUN, ORIGIN_DEATHS), "a struck nature gets no claim")
	_teardown(rig)


func _test_origin_reactions() -> void:
	var rig := _origin_rig(PackedStringArray(["wall_edges"]))
	var n: Node = rig["narrator"]
	var ledger: Node = rig["ledger"]
	var progress: PersistentProgress = rig["svc"].get("progress")
	ledger.call("strike", &"demonic", ORIGIN_RUN)
	_wait(n, STEP)
	_check(_started == PackedStringArray(["broken_demonic"]), "a struck nature plays its broken line at once, got %s" % [_started])
	_check(not progress.heard_beats.has("broken_demonic"), "broken lines may repeat (not recorded as heard)")
	_check(not ledger.call("is_armed", &"demonic"), "a strike disarms the trial")

	# A broken line queued behind a showing line outlives the queue TTL, while an ordinary queued beat expires.
	_bus.emit_signal("narration_event", &"WALL_REVEALED")
	ledger.call("strike", &"ai", ORIGIN_RUN)
	_wait(n, 20.0)
	_check(_started == PackedStringArray(["broken_demonic", "broken_ai"]), "the reactive broken_ai is not dropped by the queue TTL, got %s" % [_started])

	# At the floor the next strike recants the oldest strike (demonic): recant line first, then the broken line.
	_bus.emit_signal("narration_event", &"WALL_REVEALED")
	ledger.call("strike", &"angelic", ORIGIN_RUN)
	_wait(n, 30.0)
	var tail: PackedStringArray = _started.slice(2)
	_check(tail == PackedStringArray(["recant_demonic", "broken_angelic"]), "floor strike plays the recant then the broken line with matching params, got %s" % [tail])
	_check(ledger.call("is_armed", &"demonic"), "the recant line restates the claim and re-arms the trial")
	_check(Array(ledger.call("struck_natures")) == ["ai", "angelic"], "ledger struck list after the floor strike")

	# A recant outside the floor: recant ai directly.
	ledger.call("recant", &"ai")
	_wait(n, STEP)
	_check(_started[_started.size() - 1] == "recant_ai", "recant(ai) plays recant_ai, got %s" % [_started])
	_check(ledger.call("is_armed", &"ai"), "recant_ai re-arms the ai trial")
	_check(Array(ledger.call("struck_natures")) == ["angelic"], "ai is back")

	# The same nature can be struck again and plays again.
	_wait(n, 12.0)
	var before: int = _started.size()
	ledger.call("strike", &"ai", ORIGIN_RUN)
	_wait(n, STEP)
	_check(_started.size() == before + 1 and _started[before] == "broken_ai", "a second strike of the same nature plays its line again, got %s" % [_started])
	_teardown(rig)

	# Death-class behaviour: a broken line does not preempt a death beat, it waits behind it.
	rig = _origin_rig(PackedStringArray(["death_spikes_down"]))
	n = rig["narrator"]
	rig["ledger"].call("arm", &"ai")
	_bus.emit_signal("run_ended", &"spikes")
	_wait(n, STEP)
	_check(_started == PackedStringArray(["death_spikes_down"]), "setup: death beat on screen, got %s" % [_started])
	rig["ledger"].call("strike", &"ai", ORIGIN_RUN)
	_wait(n, STEP)
	_check(_fast_dissolves == 0 and _started.size() == 1, "a broken line does not preempt a death beat")
	_wait(n, 12.0)
	_check(_started == PackedStringArray(["death_spikes_down", "broken_ai"]), "the broken line plays after the death beat, even outside a run, got %s" % [_started])
	_teardown(rig)


func _test_origin_doubt() -> void:
	var rig := _origin_rig(PackedStringArray(["erosion_again"]))
	var n: Node = rig["narrator"]
	var ledger: Node = rig["ledger"]
	var scramble: float = (ledger.get("config") as OriginConfig).doubt_scramble
	_check(scramble > 0.0, "setup: doubt_scramble configured")
	_check(n.call("doubt_fraction", _beat(n, "erosion_again")) == 0.0, "no doubt while nothing is struck")
	ledger.call("strike", &"ai", ORIGIN_RUN)
	_check(is_equal_approx(n.call("doubt_fraction", _beat(n, "erosion_again")), scramble), "erosion_again (supports only ai) is a doubt line once ai is struck")
	_check(n.call("doubt_fraction", _beat(n, "corrupt_knows")) == 0.0, "corrupt_knows (demonic, ai) keeps its footing while demonic is alive")
	_check(n.call("doubt_fraction", _beat(n, "idle_still")) == 0.0, "a beat that also supports a deed is no doubt line")
	_check(n.call("doubt_fraction", _beat(n, "wake_first")) == 0.0, "a neutral beat is no doubt line")
	_check(n.call("doubt_fraction", _beat(n, "broken_ai")) == 0.0, "a broken line supports nothing, no doubt")
	ledger.call("strike", &"demonic", ORIGIN_RUN)
	_check(is_equal_approx(n.call("doubt_fraction", _beat(n, "corrupt_knows")), scramble), "corrupt_knows doubts once both its natures are struck")
	# The flag holds exactly when the beat supports something and all of it is struck.
	for b: NarrationBeat in (rig["config"] as NarratorConfig).beats:
		var all_struck: bool = not b.supports.is_empty()
		for s in b.supports:
			if not ["ai", "demonic"].has(s):
				all_struck = false
		var expected: float = scramble if all_struck else 0.0
		_check(is_equal_approx(n.call("doubt_fraction", b), expected), "doubt flag of %s" % b.id)
	# End to end: the narrator hands the flag to the overlay when the line starts.
	_wait(n, 30.0)
	_bus.emit_signal("narration_event", &"EROSION_HIGH")
	_wait(n, STEP)
	_check(_started[_started.size() - 1] == "erosion_again" and is_equal_approx(n.get("current_doubt"), scramble), "erosion_again plays with the doubt flag, got %s" % [_started])
	_teardown(rig)


func _test_origin_overlay() -> void:
	var config: NarratorConfig = (load(CONFIG_PATH) as NarratorConfig).duplicate()
	root.size = Vector2i(1366, 768)
	var overlay: Node = load("res://scripts/narrator/narration_overlay.gd").new()
	overlay.set("config", config)
	root.add_child(overlay)
	var beat: NarrationBeat = _beat_by_id(config, "wall_edges")
	var letters: int = beat.text.replace(" ", "").length()
	overlay.call("show_beat", beat, 0.3)
	var flags: PackedByteArray = overlay.get("_doubt")
	var flagged: int = 0
	for f in flags:
		flagged += int(f)
	_check(flagged == roundi(0.3 * letters) and flagged > 0, "a share of %d letters is unsettled, got %d" % [letters, flagged])
	var chars: PackedStringArray = overlay.get("_chars")
	for i in chars.size():
		_check(flags[i] == 0 or chars[i] != " ", "a space is never unsettled")
	overlay.call("advance", config.morph_in_seconds + 0.05)
	_check(overlay.get("phase") == 2, "doubt line reaches HOLD")
	_check(overlay.is_processing(), "a doubt line keeps animating while it rests")
	overlay.call("advance", 1.3)
	var rest: PackedVector2Array = overlay.get("_rest")
	var pos: PackedVector2Array = overlay.get("_pos")
	var alpha: PackedFloat32Array = overlay.get("_alpha")
	var limit: float = config.doubt_drift_px * float(overlay.get("_scale")) * 1.5
	var moved: int = 0
	for i in pos.size():
		if flags[i] == 0:
			_check(pos[i].is_equal_approx(rest[i]) and is_equal_approx(alpha[i], 1.0), "settled letter %d stays on its place" % i)
		else:
			moved += int(pos[i].distance_to(rest[i]) > 0.2)
			_check(pos[i].distance_to(rest[i]) <= limit, "unsettled letter %d sways calmly (%.1f px)" % [i, pos[i].distance_to(rest[i])])
			_check(alpha[i] >= 1.0 - config.doubt_alpha_dip - 0.001 and alpha[i] <= 1.001, "unsettled letter %d dips only gently" % i)
	_check(moved > 0, "unsettled letters sway around their place")
	_check("".join(overlay.get("_chars")) == beat.text.replace(" ", ""), "doubt never swaps characters")
	_check(config.doubt_hz * 1.2 <= 0.5, "doubt motion stays under 0.5 Hz")
	var before: PackedVector2Array = (overlay.get("_pos") as PackedVector2Array).duplicate()
	overlay.call("advance", 2.0)
	var changed: bool = false
	for i in pos.size():
		changed = changed or (flags[i] != 0 and not (overlay.get("_pos") as PackedVector2Array)[i].is_equal_approx(before[i]))
	_check(changed, "the unsettled letters keep moving")
	overlay.call("dissolve", false)
	overlay.call("advance", config.morph_out_seconds + 0.05)
	_check(not overlay.call("is_showing"), "the doubt line dissolves and clears")
	overlay.call("show_beat", beat)
	overlay.call("advance", config.morph_in_seconds + 0.05)
	_check(not overlay.is_processing(), "an ordinary line after a doubt line rests without processing")
	overlay.free()


func _test_floor_tie_break() -> void:
	var tweak := func(c: NarratorConfig) -> void:
		c.beats = c.beats.duplicate()
		c.beats.append(_tie_beat("tie_other", &"test_tie", 1, ["alien", "ai"], 100))
		c.beats.append(_tie_beat("tie_single", &"test_tie", 1, ["alien"], 101))
		c.beats.append(_tie_beat("tie_dual", &"test_tie", 1, ["alien", "demonic"], 102))
		c.beats.append(_tie_beat("late_dual", &"test_rank", 2, ["alien", "demonic"], 103))
		c.beats.append(_tie_beat("early_single", &"test_rank", 1, ["alien"], 104))
	var rig := _rig(tweak, true, true)
	var n: Node = rig["narrator"]
	var ledger: Node = rig["ledger"]
	n.set("run_count", 3)
	_check(String(n.call("pick_for_event", &"test_tie").id) == "tie_other", "4 alive: table order decides the tie")
	ledger.call("strike", &"angelic", 3)
	_check(String(n.call("pick_for_event", &"test_tie").id) == "tie_other", "3 alive: still table order")
	ledger.call("strike", &"ai", 3)
	_check(Array(ledger.call("alive_natures")) == ["alien", "demonic"], "setup: floor reached with alien and demonic")
	_check(String(n.call("pick_for_event", &"test_tie").id) == "tie_dual", "at the floor the beat supporting both survivors wins the tie")
	_check(String(n.call("pick_for_event", &"test_rank").id) == "early_single", "the tie-break never beats a lower min_run")
	(ledger.get("config") as OriginConfig).tie_prefer_dual_support = false
	_check(String(n.call("pick_for_event", &"test_tie").id) == "tie_other", "with tie_prefer_dual_support off the table order decides again")
	(ledger.get("config") as OriginConfig).tie_prefer_dual_support = true
	ledger.call("recant", &"ai")
	_check(String(n.call("pick_for_event", &"test_tie").id) == "tie_other", "above the floor the tie-break is off again")
	_teardown(rig)


func _tie_beat(id: String, event: StringName, min_run: int, supports: Array, order: int) -> NarrationBeat:
	var beat: NarrationBeat = _lint_beat(id, supports, [])
	beat.event = event
	beat.min_run = min_run
	beat.order = order
	beat.once = false
	return beat


func _beat_by_id(config: NarratorConfig, id: String) -> NarrationBeat:
	for b: NarrationBeat in config.beats:
		if b.id == id:
			return b
	return null
