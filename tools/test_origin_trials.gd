extends SceneTree
## Headless test of the origin trial monitor (task-041) on the real main scene. Time is advanced by calling
## OriginTrialMonitor.advance() and the game signals are emitted by hand, so no real seconds pass.
## Per trial (demonic / ai / angelic) a pass case and non-pass cases; an unarmed trial and a struck nature never
## pass; at most one strike per run, saved at once; thresholds scale after a recant; alien passes on a grown push.
## Scene nodes use the SignalBus autoload, so they are held as Variant (see test_narrator).
## Usage: godot --headless --path . --max-fps 30 -s tools/test_origin_trials.gd

const Support := preload("res://tools/test_support.gd")
const TAG := "origin_trials"
const FORM_SINGLE := &"single"
const FORM_GROWN := &"grown"
const EPS := 0.05

var _failures: PackedStringArray = []
var _passed: Array[StringName] = []
var _rig: Dictionary = {}


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _on_passed(id: StringName) -> void:
	_passed.append(id)


## A fresh main scene with a temporary save, run 1 started.
func _start() -> void:
	_passed.clear()
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var path: String = Support.isolate_save(main, TAG)
	root.add_child(main)
	var runs: Node = main.get_node("RunManager")
	root.get_node("SignalBus").intro_finished.emit()
	_rig = {
		"main": main, "path": path, "runs": runs, "ledger": main.get_node("OriginLedger"),
		"monitor": main.get_node("OriginTrialMonitor"), "player": main.get_node("Player"),
		"loader": main.get_node("World/MapLoader"), "bus": root.get_node("SignalBus"),
	}
	_rig.bus.origin_trial_passed.connect(_on_passed)
	_check(runs.phase == 1, "run did not start")


func _stop() -> void:
	_rig.bus.origin_trial_passed.disconnect(_on_passed)
	_rig.main.queue_free()
	await process_frame


func _erode(amount: float) -> void:
	_rig.bus.erosion_changed.emit(amount, Color.WHITE)


func _place(cell: Vector2i) -> void:
	_rig.player.velocity = Vector3.ZERO
	_rig.player.global_position = _rig.loader.cell_to_world(cell)


## Idle clock restarts the way the player does it: moves, then stands still.
func _stand_still() -> void:
	_rig.bus.player_motion_changed.emit(true)
	_rig.bus.player_motion_changed.emit(false)


func _saved_struck() -> PackedStringArray:
	var saved: PersistentProgress = ResourceLoader.load(_rig.path, "", ResourceLoader.CACHE_MODE_IGNORE) as PersistentProgress
	return saved.struck_natures if saved != null else PackedStringArray(["<no save>"])


## Light-source cell types as the monitor sees them, and the floor cell farthest from / nearest to them.
func _light_distance(cell: Vector2i) -> float:
	var data: MapData = _rig.loader.data
	var best: float = INF
	for y in data.height:
		for x in data.width:
			var t: StringName = data.type_at(Vector2i(x, y))
			if t == MapLegend.ITEM or t == MapLegend.SPIKES or t == MapLegend.CORRUPT:
				best = minf(best, Vector2(cell).distance_to(Vector2(x, y)))
	return best


func _floor_cell(far: bool) -> Vector2i:
	var data: MapData = _rig.loader.data
	var pick := Vector2i(-1, -1)
	var best: float = -1.0 if far else INF
	for y in data.height:
		for x in data.width:
			var c := Vector2i(x, y)
			if data.type_at(c) != MapLegend.FLOOR:
				continue
			var d: float = _light_distance(c)
			if (far and d > best) or (not far and d < best):
				best = d
				pick = c
	return pick


func _run() -> void:
	# --- Demonic -----------------------------------------------------------------------------------------------
	await _case_demonic_pass()
	await _case_demonic_non_pass()
	# --- AI ----------------------------------------------------------------------------------------------------
	await _case_ai_pass()
	await _case_ai_non_pass()
	# --- Angelic -----------------------------------------------------------------------------------------------
	await _case_angelic_pass()
	await _case_angelic_non_pass()
	# --- Gating, cap, scaling ----------------------------------------------------------------------------------
	await _case_unarmed()
	await _case_struck()
	await _case_one_strike_per_run()
	await _case_scaling()
	await _case_alien()

	Support.remove_file("user://test_progress_%s.tres" % TAG)
	if _failures.is_empty():
		print("PASS test_origin_trials")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_origin_trials")
		quit(1)


func _case_demonic_pass() -> void:
	_start()
	var trial: OriginTrial = _rig.ledger.config.find(&"demonic").trial
	_check(trial.erosion_fraction > 0.0 and trial.seconds > 0.0, "demonic thresholds must come from the trial resource")
	_rig.ledger.arm(&"demonic")
	_erode(0.4)
	_erode(trial.erosion_fraction + 0.05)
	_rig.monitor.advance(trial.seconds * 3.0)
	_check(_passed.is_empty(), "demonic passed while still in the corruption")
	_erode(0.5)
	_check(_rig.monitor.is_processing(), "monitor must process while the escape timer runs")
	_rig.monitor.advance(trial.seconds - 0.1)
	_check(_passed.is_empty(), "demonic passed before the survive time")
	_rig.monitor.advance(0.2)
	_check(_passed == [&"demonic"], "demonic must pass once, got %s" % [_passed])
	_check(_rig.ledger.struck_natures() == PackedStringArray(["demonic"]), "demonic must be struck")
	_check(_saved_struck() == PackedStringArray(["demonic"]), "the strike must be saved at once, got %s" % [_saved_struck()])
	_check(not _rig.monitor.is_processing(), "monitor must stop processing after the pass")
	await _stop()


func _case_demonic_non_pass() -> void:
	# Dying in the corruption.
	_start()
	var trial: OriginTrial = _rig.ledger.config.find(&"demonic").trial
	_rig.ledger.arm(&"demonic")
	_erode(trial.erosion_fraction + 0.1)
	_rig.bus.run_end_requested.emit(&"corruption")
	_rig.monitor.advance(trial.seconds * 10.0)
	_check(_passed.is_empty(), "demonic passed after dying in the corruption")
	await _stop()

	# Leaving before the erosion was high.
	_start()
	_rig.ledger.arm(&"demonic")
	_erode(0.3)
	_erode(0.1)
	_rig.monitor.advance(trial.seconds * 10.0)
	_check(_passed.is_empty(), "demonic passed without reaching high erosion")
	await _stop()

	# Eroding again restarts the survive time.
	_start()
	_rig.ledger.arm(&"demonic")
	_erode(trial.erosion_fraction + 0.1)
	_erode(0.5)
	_rig.monitor.advance(trial.seconds - 1.0)
	_erode(0.6)
	_rig.monitor.advance(trial.seconds * 3.0)
	_check(_passed.is_empty(), "demonic passed although the player went back into the corruption")
	_erode(0.4)
	_rig.monitor.advance(trial.seconds - 1.0)
	_check(_passed.is_empty(), "the survive time must restart after eroding again")
	_rig.monitor.advance(2.0)
	_check(_passed == [&"demonic"], "demonic must pass after a full clean survive time")
	await _stop()


func _case_ai_pass() -> void:
	_start()
	var trial: OriginTrial = _rig.ledger.config.find(&"ai").trial
	_check(trial.seconds > 0.0, "ai threshold must come from the trial resource")
	_rig.ledger.arm(&"ai")
	_rig.bus.entity_form_changed.emit(FORM_SINGLE, true)
	_check(_rig.monitor.is_processing(), "monitor must process while the single form timer runs")
	_rig.monitor.advance(trial.seconds - 1.0)
	_check(_passed.is_empty(), "ai passed before the survive time")
	_rig.monitor.advance(1.5)
	_check(_passed == [&"ai"], "ai must pass once, got %s" % [_passed])
	_check(_saved_struck() == PackedStringArray(["ai"]), "the ai strike must be saved at once")
	await _stop()

	# The claim lands after the form switch (it is played by the same event): the time still counts from the choice.
	_start()
	_rig.bus.entity_form_changed.emit(FORM_SINGLE, true)
	_rig.monitor.advance(trial.seconds * 5.0)
	_check(_passed.is_empty(), "an unarmed ai trial must not tick or pass")
	_rig.ledger.arm(&"ai")
	_rig.monitor.advance(trial.seconds + 0.1)
	_check(_passed == [&"ai"], "ai must pass once armed after the choice")
	await _stop()


func _case_ai_non_pass() -> void:
	_start()
	var trial: OriginTrial = _rig.ledger.config.find(&"ai").trial
	_rig.ledger.arm(&"ai")
	_rig.bus.entity_form_changed.emit(FORM_SINGLE, true)
	_rig.monitor.advance(trial.seconds * 0.5)
	_rig.bus.entity_form_changed.emit(FORM_GROWN, true)
	_rig.monitor.advance(trial.seconds * 5.0)
	_check(_passed.is_empty(), "ai passed after switching back before the survive time")
	await _stop()

	# The form restored at a run start is not a choice.
	_start()
	_rig.ledger.arm(&"ai")
	_rig.bus.entity_form_changed.emit(FORM_SINGLE, false)
	_rig.monitor.advance(trial.seconds * 5.0)
	_check(_passed.is_empty(), "ai passed from a restored (not chosen) single form")
	await _stop()

	# Dying resets: the next run needs a new choice.
	_start()
	_rig.ledger.arm(&"ai")
	_rig.bus.entity_form_changed.emit(FORM_SINGLE, true)
	_rig.monitor.advance(trial.seconds * 0.5)
	_rig.bus.run_end_requested.emit(&"spikes")
	_rig.runs.start_run()
	_rig.monitor.advance(trial.seconds * 5.0)
	_check(_passed.is_empty(), "ai passed across a death")
	await _stop()


func _case_angelic_pass() -> void:
	_start()
	var trial: OriginTrial = _rig.ledger.config.find(&"angelic").trial
	_check(trial.seconds > 0.0 and trial.distance > 0, "angelic thresholds must come from the trial resource")
	var far: Vector2i = _floor_cell(true)
	_check(_light_distance(far) >= float(trial.distance), "test map has no cell %d cells from every light" % trial.distance)
	_rig.ledger.arm(&"angelic")
	_place(far)
	_stand_still()
	_rig.monitor.advance(trial.seconds - 1.0)
	_check(_passed.is_empty(), "angelic passed before the idle time")
	_rig.monitor.advance(1.5)
	_check(_passed == [&"angelic"], "angelic must pass once, got %s" % [_passed])
	_check(_saved_struck() == PackedStringArray(["angelic"]), "the angelic strike must be saved at once")
	await _stop()


func _case_angelic_non_pass() -> void:
	# Idle next to a light.
	_start()
	var trial: OriginTrial = _rig.ledger.config.find(&"angelic").trial
	var near: Vector2i = _floor_cell(false)
	_check(_light_distance(near) < float(trial.distance), "test map has no cell near a light")
	_rig.ledger.arm(&"angelic")
	_place(near)
	_stand_still()
	_rig.monitor.advance(trial.seconds * 10.0)
	_check(_passed.is_empty(), "angelic passed while idle near a light")
	_check(not _rig.monitor.is_processing(), "no per-frame work while idling near a light")
	await _stop()

	# Moving restarts the idle time.
	_start()
	_rig.ledger.arm(&"angelic")
	_place(_floor_cell(true))
	_stand_still()
	_rig.monitor.advance(trial.seconds - 1.0)
	_stand_still()
	_rig.monitor.advance(trial.seconds - 1.0)
	_check(_passed.is_empty(), "angelic passed although the player moved in between")
	_rig.bus.player_motion_changed.emit(true)
	_rig.monitor.advance(trial.seconds * 10.0)
	_check(_passed.is_empty(), "angelic passed while moving")
	_check(not _rig.monitor.is_processing(), "no per-frame work while moving")
	await _stop()


func _case_unarmed() -> void:
	_start()
	var d: OriginTrial = _rig.ledger.config.find(&"demonic").trial
	var a: OriginTrial = _rig.ledger.config.find(&"ai").trial
	var g: OriginTrial = _rig.ledger.config.find(&"angelic").trial
	_place(_floor_cell(true))
	_stand_still()
	_erode(d.erosion_fraction + 0.1)
	_erode(0.2)
	_rig.bus.entity_form_changed.emit(FORM_SINGLE, true)
	_rig.monitor.advance(maxf(d.seconds, maxf(a.seconds, g.seconds)) * 5.0)
	_check(_passed.is_empty(), "an unarmed trial passed: %s" % [_passed])
	_check(_rig.ledger.struck_natures().is_empty(), "nothing may be struck without an armed trial")
	_check(not _rig.monitor.is_processing(), "no per-frame work while no trial is armed")
	await _stop()


func _case_struck() -> void:
	_start()
	var d: OriginTrial = _rig.ledger.config.find(&"demonic").trial
	_rig.ledger.arm(&"demonic")
	_check(_rig.ledger.strike(&"demonic", 0), "setup: strike demonic")
	_rig.ledger.arm(&"demonic")
	_check(not _rig.ledger.is_armed(&"demonic"), "a struck nature cannot be armed")
	_erode(d.erosion_fraction + 0.1)
	_erode(0.2)
	_rig.monitor.advance(d.seconds * 5.0)
	_check(_passed.is_empty(), "a struck nature's trial passed")
	_check(_rig.ledger.struck_natures() == PackedStringArray(["demonic"]), "struck list changed")
	await _stop()


## Two armed trials pass in one run: only the first strikes; the second strikes in the next run. Saved at once.
func _case_one_strike_per_run() -> void:
	_start()
	var d: OriginTrial = _rig.ledger.config.find(&"demonic").trial
	var a: OriginTrial = _rig.ledger.config.find(&"ai").trial
	_rig.ledger.arm(&"demonic")
	_rig.ledger.arm(&"ai")
	_erode(d.erosion_fraction + 0.1)
	_erode(0.2)
	_rig.bus.entity_form_changed.emit(FORM_SINGLE, true)
	_rig.monitor.advance(maxf(d.seconds, a.seconds) + 1.0)
	_check(_passed.size() == 2, "both trials should have reported a pass, got %s" % [_passed])
	_check(_rig.ledger.struck_natures().size() == 1, "at most one strike per run, got %s" % [_rig.ledger.struck_natures()])
	_check(_saved_struck().size() == 1, "the single strike must be on disk, got %s" % [_saved_struck()])
	var first: String = _rig.ledger.struck_natures()[0]
	var second: StringName = &"ai" if first == "demonic" else &"demonic"
	_check(_rig.ledger.is_armed(second), "the refused trial stays armed")
	_rig.monitor.advance(a.seconds * 10.0)
	_check(_rig.ledger.struck_natures().size() == 1 and _passed.size() == 2, "a refused trial must not re-report within the run")

	_rig.runs.start_run()
	if second == &"demonic":
		_erode(d.erosion_fraction + 0.1)
		_erode(0.2)
	else:
		_rig.bus.entity_form_changed.emit(FORM_SINGLE, true)
	_rig.monitor.advance(maxf(d.seconds, a.seconds) + 1.0)
	_check(_rig.ledger.struck_natures().size() == 2, "the second strike should land in the next run, got %s" % [_rig.ledger.struck_natures()])
	_check(_saved_struck().size() == 2, "the second strike must be on disk")
	await _stop()


## After a strike and a recant the trial is harder: seconds * retry_scale per previous strike.
func _case_scaling() -> void:
	_start()
	var d: OriginTrial = _rig.ledger.config.find(&"demonic").trial
	var scale: float = _rig.ledger.config.retry_scale
	_check(scale > 1.0, "retry_scale must make a retry harder")
	_rig.ledger.strike(&"demonic", 0)
	_rig.ledger.recant(&"demonic")
	_check(is_equal_approx(_rig.ledger.trial_scale(&"demonic"), scale), "trial_scale after one strike")
	_rig.ledger.arm(&"demonic")
	_erode(d.erosion_fraction + 0.1)
	_erode(0.2)
	_rig.monitor.advance(d.seconds + EPS)
	_check(_passed.is_empty(), "the recanted demonic trial passed at the unscaled time")
	_rig.monitor.advance(d.seconds * scale - d.seconds)
	_check(_passed == [&"demonic"], "the recanted demonic trial must pass at the scaled time, got %s" % [_passed])
	await _stop()


func _case_alien() -> void:
	_start()
	var t: OriginTrial = _rig.ledger.config.find(&"alien").trial
	_check(t.kind == OriginTrial.Kind.OBJECT_MOVED and not t.dormant, "setup: alien trial is OBJECT_MOVED and not dormant")
	# Unarmed: a grown push does nothing.
	_rig.bus.object_moved.emit(0, Vector2i.ZERO, Vector2i.ONE, FORM_GROWN)
	_check(_passed.is_empty(), "an unarmed alien trial passed")
	_rig.ledger.arm(&"alien")
	# Single form never counts.
	_rig.bus.object_moved.emit(0, Vector2i.ZERO, Vector2i.ONE, FORM_SINGLE)
	_check(_passed.is_empty(), "a single-form move passed the alien trial")
	_rig.bus.object_moved.emit(0, Vector2i.ZERO, Vector2i.ONE, FORM_GROWN)
	_check(_passed == [&"alien"], "a grown push while armed must pass alien, got %s" % [_passed])
	_check(_rig.ledger.struck_natures() == PackedStringArray(["alien"]), "alien struck, got %s" % [_rig.ledger.struck_natures()])
	_rig.bus.object_moved.emit(1, Vector2i.ZERO, Vector2i.ONE, FORM_GROWN)
	_check(_passed.size() == 1, "alien reports once per run")
	await _stop()

	# Struck nature: never passes again.
	_start()
	_rig.ledger.arm(&"alien")
	_rig.ledger.strike(&"alien", 0)
	_rig.bus.object_moved.emit(0, Vector2i.ZERO, Vector2i.ONE, FORM_GROWN)
	_check(_passed.is_empty(), "a struck alien trial passed")
	await _stop()

	# One strike per run: alien after demonic in the same run is refused, stays armed.
	_start()
	var d: OriginTrial = _rig.ledger.config.find(&"demonic").trial
	_rig.ledger.arm(&"demonic")
	_rig.ledger.arm(&"alien")
	_erode(d.erosion_fraction + 0.1)
	_erode(0.2)
	_rig.monitor.advance(d.seconds + 1.0)
	_rig.bus.object_moved.emit(0, Vector2i.ZERO, Vector2i.ONE, FORM_GROWN)
	_check(_passed.size() == 2, "both reported, got %s" % [_passed])
	_check(_rig.ledger.struck_natures() == PackedStringArray(["demonic"]), "only the first pass strikes, got %s" % [_rig.ledger.struck_natures()])
	_check(_rig.ledger.is_armed(&"alien"), "the refused alien trial stays armed")
	await _stop()
