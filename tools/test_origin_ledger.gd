extends SceneTree
## Headless test of the origin ledger (task-039): resources load, 1000 random operation sequences never break the
## invariant (>= 2 natures alive, deeds never struck), the floor recant, the per-run cap, repair of invalid saves
## and the persistence round trip. Only temporary save paths are used; they are removed at the end.
## OriginLedger and SaveService use the SignalBus autoload, so the test holds them as Variant (see test_narrator).
## Usage: godot --headless --path . --max-fps 30 -s tools/test_origin_ledger.gd

const Support := preload("res://tools/test_support.gd")
const PATH := "user://test_progress_origin.tres"
const CONFIG_PATH := "res://resources/config/origin_config.tres"
const SEQUENCES := 1000
const OPS_PER_SEQUENCE := 14
const SCRIPT_DIRS: PackedStringArray = ["res://scripts/"]
const STATE_FIELDS: PackedStringArray = ["struck_natures", "armed_trials", "strike_counts", "last_strike_run"]
const STATE_WRITERS: PackedStringArray = [
	"res://scripts/origin/origin_ledger.gd", "res://scripts/core/persistent_progress.gd",
	"res://scripts/core/save_service.gd",
]

var _failures: PackedStringArray = []
var _signals: PackedStringArray = []
var _recants: int = 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _rig(path: String = PATH, tweak: Callable = Callable()) -> Dictionary:
	var cfg := SaveConfig.new()
	cfg.save_path = path
	var svc: Variant = load("res://scripts/core/save_service.gd").new()
	svc.config = cfg
	root.add_child(svc)
	var config: OriginConfig = (load(CONFIG_PATH) as OriginConfig).duplicate()
	if tweak.is_valid():
		tweak.call(config)
	var ledger: Variant = load("res://scripts/origin/origin_ledger.gd").new()
	ledger.config = config
	ledger.save_service = svc
	root.add_child(ledger)
	return {"svc": svc, "ledger": ledger, "config": config}


func _teardown(rig: Dictionary) -> void:
	(rig["ledger"] as Node).free()
	(rig["svc"] as Node).free()


func _write_save(progress: PersistentProgress) -> void:
	Support.remove_file(PATH)
	ResourceSaver.save(progress, PATH)


func _run() -> void:
	Support.remove_file(PATH)
	_test_resources()
	_test_floor_and_cap()
	_test_signals_and_arming()
	_test_random_sequences()
	_test_repair()
	await _test_persistence()
	_test_sole_writer()
	_test_config_clamp()

	Support.remove_file(PATH)
	if _failures.is_empty():
		print("PASS test_origin_ledger")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_origin_ledger")
		quit(1)


func _test_resources() -> void:
	var config: OriginConfig = load(CONFIG_PATH)
	_check(config != null, "origin_config.tres loads")
	_check(config.nature_ids() == PackedStringArray(["alien", "ai", "demonic", "angelic"]), "4 natures, got %s" % [config.nature_ids()])
	_check(config.deed_ids() == PackedStringArray(["hero", "villain"]), "2 deeds, got %s" % [config.deed_ids()])
	for h in config.hypotheses:
		_check(h.sigil != "" and h.label != "", "%s has a sigil and a label" % h.id)
		_check(load("res://resources/origin/%s.tres" % h.id) is OriginHypothesis, "%s.tres loads" % h.id)
		if h.is_nature():
			_check(h.trial != null, "nature %s has a trial" % h.id)
			_check(h.claim_beat_id != "" and h.broken_beat_id != "" and h.recant_beat_id != "", "nature %s names its beats" % h.id)
		else:
			_check(h.trial == null, "deed %s has no trial" % h.id)
	var kinds: Dictionary = {}
	for id in config.nature_ids():
		kinds[config.find(StringName(id)).trial.kind] = true
	_check(kinds.size() == 4, "the four natures use the four trial kinds")
	_check(config.find(&"demonic").trial.seconds == 15.0 and config.find(&"ai").trial.seconds == 60.0, "trial seconds from the design")
	_check(config.find(&"angelic").trial.distance == 6 and config.find(&"alien").trial.requires_entity_unlocked, "angelic distance and alien dormancy from the design")
	_check(config.min_alive_nature == 2 and config.max_strikes_per_run == 1 and config.retry_scale == 1.5, "config defaults from the design")


func _test_floor_and_cap() -> void:
	var rig := _rig()
	var ledger: Variant = rig["ledger"]
	var progress: PersistentProgress = rig["svc"].progress
	_check(ledger.alive_natures().size() == 4, "all four natures start alive")
	_check(not ledger.strike(&"hero") and not ledger.strike(&"villain"), "deeds can never be struck")
	_check(not ledger.strike(&"nonsense"), "unknown ids cannot be struck")
	_check(ledger.request_strike(&"alien", 1), "first strike in run 1 works")
	_check(not ledger.request_strike(&"ai", 1), "second strike in the same run is capped")
	_check(ledger.struck_natures() == PackedStringArray(["alien"]), "cap blocked the second strike")
	_check(not ledger.request_strike(&"alien", 2), "an already struck nature stays struck")
	_check(ledger.request_strike(&"ai", 2), "the next run may strike again")
	_check(ledger.alive_natures().size() == 2, "at the floor: two alive")
	# Striking a third nature recants the oldest strike (alien) first.
	_check(ledger.request_strike(&"demonic", 3), "a strike at the floor still succeeds")
	_check(ledger.struck_natures() == PackedStringArray(["ai", "demonic"]), "oldest strike recanted, got %s" % [ledger.struck_natures()])
	_check(ledger.is_alive(&"alien") and ledger.alive_natures().size() == 2, "alien is back, two alive")
	_check(ledger.strike_count(&"alien") == 1 and is_equal_approx(ledger.trial_scale(&"alien"), 1.5), "recanted nature is harder to strike again (x1.5)")
	_check(is_equal_approx(ledger.trial_scale(&"angelic"), 1.0), "a never-struck nature has scale 1")
	_check(progress.last_strike_run == 3, "last_strike_run stored")
	_check(not ledger.recant(&"angelic") and ledger.recant(&"ai") and not ledger.recant(&"ai"), "recant only works on struck natures, once")
	_teardown(rig)
	Support.remove_file(PATH)


func _test_signals_and_arming() -> void:
	var bus: Node = root.get_node("SignalBus")
	var rig := _rig()
	var ledger: Variant = rig["ledger"]
	var progress: PersistentProgress = rig["svc"].progress
	_signals = PackedStringArray()
	bus.connect("origin_struck", func(id: StringName) -> void: _signals.append("struck:%s" % id))
	bus.connect("origin_recanted", func(id: StringName) -> void: _signals.append("recanted:%s" % id))
	bus.connect("origin_ledger_changed", func(alive: PackedStringArray, struck: PackedStringArray) -> void: _signals.append("changed:%d/%d" % [alive.size(), struck.size()]))
	progress.run_count = 1
	bus.emit_signal("origin_trial_passed", &"demonic")
	_check(ledger.struck_natures().is_empty(), "a trial that is not armed cannot strike")
	bus.emit_signal("origin_claim_heard", &"demonic")
	bus.emit_signal("origin_claim_heard", &"hero")
	_check(ledger.is_armed(&"demonic") and not ledger.is_armed(&"hero"), "a claim arms a nature, never a deed")
	bus.emit_signal("origin_trial_passed", &"demonic")
	_check(ledger.struck_natures() == PackedStringArray(["demonic"]), "an armed trial strikes via the bus")
	_check(not ledger.is_armed(&"demonic"), "a strike disarms the trial")
	bus.emit_signal("origin_claim_heard", &"demonic")
	_check(not ledger.is_armed(&"demonic"), "a struck nature cannot be armed")
	_check(_signals.has("struck:demonic") and _signals.has("changed:3/1"), "signals emitted, got %s" % [_signals])
	ledger.recant(&"demonic")
	_check(_signals.has("recanted:demonic") and _signals.has("changed:4/0"), "recant signals, got %s" % [_signals])
	_check(not ledger.is_armed(&"demonic"), "a recanted nature waits for its claim again")
	_teardown(rig)
	Support.remove_file(PATH)


func _test_random_sequences() -> void:
	var rig := _rig()
	var ledger: Variant = rig["ledger"]
	var svc: Variant = rig["svc"]
	var ids: Array[StringName] = [&"alien", &"ai", &"demonic", &"angelic", &"hero", &"villain", &"bogus"]
	var deeds: Array[StringName] = [&"hero", &"villain"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 39
	var bad: int = 0
	var struck_total: int = 0
	_recants = 0
	var counter := func(_id: StringName) -> void: _recants += 1
	root.get_node("SignalBus").connect("origin_recanted", counter)
	for s in SEQUENCES:
		svc.progress = PersistentProgress.new()
		var run: int = 0
		for op in OPS_PER_SEQUENCE:
			var id: StringName = ids[rng.randi() % ids.size()]
			match rng.randi() % 5:
				0, 1:
					run += rng.randi() % 2
					if ledger.request_strike(id, run):
						struck_total += 1
				2:
					if ledger.strike(id):
						struck_total += 1
				3:
					ledger.recant(id)
				_:
					ledger.arm(id)
			var struck: PackedStringArray = ledger.struck_natures()
			var natures: PackedStringArray = ledger.config.nature_ids()
			var alive_count: int = 0
			for n in natures:
				if not struck.has(n):
					alive_count += 1
			var clean: bool = alive_count >= 2 and ledger.alive_natures().size() == alive_count
			for d in deeds:
				clean = clean and not struck.has(String(d)) and not ledger.is_armed(d)
			for t in struck:
				clean = clean and natures.has(t)
			for i in struck.size():
				clean = clean and struck.find(struck[i]) == i
			if not clean:
				bad += 1
	root.get_node("SignalBus").disconnect("origin_recanted", counter)
	_check(bad == 0, "%d of %d random operations broke the invariant" % [bad, SEQUENCES * OPS_PER_SEQUENCE])
	_check(struck_total > SEQUENCES and _recants > 0, "the random sequences exercised strikes (%d) and floor recants (%d)" % [struck_total, _recants])
	_teardown(rig)
	Support.remove_file(PATH)


func _test_repair() -> void:
	# 3 struck natures: the newest strike is recanted, with a warning.
	var progress := PersistentProgress.new()
	progress.struck_natures = PackedStringArray(["ai", "alien", "demonic"])
	progress.strike_counts = {"ai": 1, "alien": 1, "demonic": 1}
	_write_save(progress)
	var rig := _rig()
	var ledger: Variant = rig["ledger"]
	_check(ledger.struck_natures() == PackedStringArray(["ai", "alien"]), "3 struck repaired to 2, newest recanted, got %s" % [ledger.struck_natures()])
	_check(ledger.alive_natures().size() == 2, "two natures alive after repair")
	_check(not ledger.repair_log.is_empty() and "demonic" in ledger.repair_log[0], "repair was logged (push_warning), log: %s" % [ledger.repair_log])
	_teardown(rig)

	# 4 struck: down to 2 alive, oldest two kept.
	progress = PersistentProgress.new()
	progress.struck_natures = PackedStringArray(["ai", "alien", "demonic", "angelic"])
	_write_save(progress)
	rig = _rig()
	ledger = rig["ledger"]
	_check(ledger.struck_natures() == PackedStringArray(["ai", "alien"]), "4 struck repaired to the 2 oldest, got %s" % [ledger.struck_natures()])
	# The repair was saved: a fresh launch finds it clean and silent.
	_teardown(rig)
	rig = _rig()
	ledger = rig["ledger"]
	_check(ledger.struck_natures() == PackedStringArray(["ai", "alien"]) and ledger.repair_log.is_empty(), "the repaired save was written")
	_teardown(rig)

	# Unknown ids, deeds and duplicates are dropped; armed trials of struck natures too.
	progress = PersistentProgress.new()
	progress.struck_natures = PackedStringArray(["hero", "nonsense", "ai", "ai"])
	progress.armed_trials = PackedStringArray(["ai", "bogus", "demonic", "demonic", "villain"])
	progress.strike_counts = {"ai": 2, "ghost": 5}
	progress.last_strike_run = -4
	_write_save(progress)
	rig = _rig()
	ledger = rig["ledger"]
	_check(ledger.struck_natures() == PackedStringArray(["ai"]), "unknown ids and deeds dropped, got %s" % [ledger.struck_natures()])
	_check((rig["svc"].progress as PersistentProgress).armed_trials == PackedStringArray(["demonic"]), "armed trials cleaned, got %s" % [(rig["svc"].progress as PersistentProgress).armed_trials])
	_check(not (rig["svc"].progress as PersistentProgress).strike_counts.has("ghost") and ledger.strike_count(&"ai") == 2, "strike counts cleaned")
	_check((rig["svc"].progress as PersistentProgress).last_strike_run == 0, "negative last_strike_run sanitized")
	_teardown(rig)

	# A missing or garbage field set loads as an empty ledger.
	Support.remove_file(PATH)
	rig = _rig()
	ledger = rig["ledger"]
	_check(ledger.struck_natures().is_empty() and ledger.repair_log.is_empty(), "no save = untouched ledger")
	_teardown(rig)
	Support.remove_file(PATH)


func _test_persistence() -> void:
	var rig := _rig()
	var ledger: Variant = rig["ledger"]
	(rig["svc"].progress as PersistentProgress).run_count = 4
	ledger.arm(&"angelic")
	ledger.arm(&"ai")
	ledger.request_strike(&"alien", 4)
	ledger.request_strike(&"ai", 5)
	_check(FileAccess.file_exists(PATH), "a strike is saved at once")
	_teardown(rig)
	await process_frame
	rig = _rig()
	ledger = rig["ledger"]
	var progress: PersistentProgress = rig["svc"].progress
	_check(ledger.struck_natures() == PackedStringArray(["alien", "ai"]), "struck natures round trip in order, got %s" % [ledger.struck_natures()])
	_check(progress.armed_trials == PackedStringArray(["angelic"]), "armed trials round trip, got %s" % [progress.armed_trials])
	_check(ledger.strike_count(&"alien") == 1 and ledger.strike_count(&"ai") == 1 and ledger.strike_count(&"demonic") == 0, "strike counts round trip")
	_check(progress.last_strike_run == 5, "last_strike_run round trip")
	_check(ledger.repair_log.is_empty(), "a valid save needs no repair")
	_check(not ledger.request_strike(&"demonic", 5), "the per-run cap survives a reload")
	_check(ledger.request_strike(&"demonic", 6) and ledger.struck_natures() == PackedStringArray(["ai", "demonic"]), "after reload the floor rule still recants the oldest")
	_teardown(rig)
	Support.remove_file(PATH)


## OriginLedger is the only runtime writer: no other script under scripts/ may mention the ledger state fields.
func _test_sole_writer() -> void:
	var offenders := PackedStringArray()
	for dir in SCRIPT_DIRS:
		_scan(dir, offenders)
	_check(offenders.is_empty(), "scripts touching the ledger state besides the ledger: %s" % [offenders])


func _scan(dir: String, offenders: PackedStringArray) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir + sub + "/", offenders)
	for file in DirAccess.get_files_at(dir):
		var path: String = dir + file
		if not file.ends_with(".gd") or STATE_WRITERS.has(path):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		for field in STATE_FIELDS:
			if text.contains(field):
				offenders.append("%s (%s)" % [path, field])


func _test_config_clamp() -> void:
	var rig := _rig(PATH, func(c: OriginConfig) -> void: c.min_alive_nature = 1)
	var ledger: Variant = rig["ledger"]
	_check(ledger.config.effective_min_alive() == 2, "min_alive_nature below 2 is clamped to 2")
	ledger.request_strike(&"alien", 1)
	ledger.request_strike(&"ai", 2)
	ledger.request_strike(&"demonic", 3)
	_check(ledger.alive_natures().size() == 2, "a clamped config still keeps two alive")
	_teardown(rig)
	Support.remove_file(PATH)
