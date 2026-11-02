class_name OriginLedger
extends Node
## The ONLY writer of the origin rule-out state in PersistentProgress (struck_natures, armed_trials,
## strike_counts, last_strike_run). Logic node right after SaveService.
##
## Invariant (docs/game_design.md, Origin Contradiction and Rule-Out System): at least
## OriginConfig.effective_min_alive() natures (never below 2) are alive, and deeds are never struck.
## It holds by induction: strike() recants the oldest strike first when the floor would break, recant()
## only raises the alive count, and load repair recants the newest strikes. Nothing else changes the list.
##
## Trials are checked elsewhere (task-041); the monitor emits SignalBus.origin_trial_passed(id), or calls
## request_strike() directly. The narrator (task-042) arms trials through SignalBus.origin_claim_heard(id).

@export var config: OriginConfig
@export var save_service: SaveService

## Messages of the last load repair (also pushed as warnings); lets tests assert the repair was logged.
var repair_log: PackedStringArray = PackedStringArray()

## Strikes made in the run `_cap_run` (the cap counter; reset when a different run asks).
var _cap_run: int = -1
var _cap_count: int = 0


func _ready() -> void:
	if config == null:
		config = OriginConfig.new()
	if config.min_alive_nature < OriginConfig.HARD_MIN_ALIVE_NATURE:
		push_error("[OriginLedger] min_alive_nature %d is below the guarantee floor, using %d" % [config.min_alive_nature, OriginConfig.HARD_MIN_ALIVE_NATURE])
	if save_service != null:
		save_service.progress_loaded.connect(repair)
		repair()
	SignalBus.origin_trial_passed.connect(_on_trial_passed)
	SignalBus.origin_claim_heard.connect(_on_claim_heard)


# --- Queries ---------------------------------------------------------------------------------------------------

func struck_natures() -> PackedStringArray:
	return _progress().struck_natures


func alive_natures() -> PackedStringArray:
	var out := PackedStringArray()
	var struck: PackedStringArray = _progress().struck_natures
	for id in config.nature_ids():
		if not struck.has(id):
			out.append(id)
	return out


func is_nature(id: StringName) -> bool:
	var h: OriginHypothesis = config.find(id)
	return h != null and h.is_nature()


func is_alive(id: StringName) -> bool:
	return is_nature(id) and not _progress().struck_natures.has(String(id))


func is_armed(id: StringName) -> bool:
	return _progress().armed_trials.has(String(id))


## True when the narrator may play this nature's claim: an alive nature with a live trial that is not armed yet.
func is_claimable(id: StringName) -> bool:
	if not is_alive(id) or is_armed(id):
		return false
	var trial: OriginTrial = config.find(id).trial
	return trial != null and not trial.dormant


func strike_count(id: StringName) -> int:
	return int(_progress().strike_counts.get(String(id), 0))


## Threshold multiplier of a nature's trial: retry_scale per previous strike (1.0 for a never-struck nature).
func trial_scale(id: StringName) -> float:
	return pow(config.retry_scale, strike_count(id))


# --- Operations (the only ways the state changes) -------------------------------------------------------------

## Entry point for the trial monitor. Strikes `id` unless it is not an alive nature or the per-run cap is used up.
## `run_index` is the persistent run number (PersistentProgress.run_count). Returns true when the nature was struck.
func request_strike(id: StringName, run_index: int) -> bool:
	if not is_alive(id):
		return false
	if _strikes_in_run(run_index) >= config.max_strikes_per_run:
		return false
	if not strike(id, run_index):
		return false
	_cap_count += 1
	return true


## Strikes a nature. No-op (false) for a deed, an unknown or an already struck id. When striking would drop the
## alive natures below the floor, the oldest strike is recanted first. `run_index` > 0 is stored as last_strike_run.
func strike(id: StringName, run_index: int = 0) -> bool:
	if not is_alive(id):
		return false
	var progress: PersistentProgress = _progress()
	var floor_alive: int = config.effective_min_alive()
	var recanted: StringName = &""
	if alive_natures().size() - 1 < floor_alive:
		if progress.struck_natures.is_empty():
			return false
		recanted = StringName(progress.struck_natures[0])
		progress.struck_natures.remove_at(0)
	progress.struck_natures.append(String(id))
	progress.strike_counts[String(id)] = strike_count(id) + 1
	_disarm(id)
	if run_index > 0:
		progress.last_strike_run = run_index
	_commit()
	if recanted != &"":
		SignalBus.origin_recanted.emit(recanted)
	SignalBus.origin_struck.emit(id)
	_announce()
	return true


## Brings a struck nature back. No-op (false) for anything that is not struck. Its trial stays unarmed until the
## narrator restates the claim (origin_claim_heard).
func recant(id: StringName) -> bool:
	var progress: PersistentProgress = _progress()
	var at: int = progress.struck_natures.find(String(id))
	if at < 0:
		return false
	progress.struck_natures.remove_at(at)
	_commit()
	SignalBus.origin_recanted.emit(id)
	_announce()
	return true


## Arms the trial of an alive nature (its claim was heard). False for deeds, struck or unknown natures.
func arm(id: StringName) -> bool:
	if not is_alive(id) or config.find(id).trial == null:
		return false
	var progress: PersistentProgress = _progress()
	if progress.armed_trials.has(String(id)):
		return true
	progress.armed_trials.append(String(id))
	_commit()
	_announce()
	return true


## Makes loaded data satisfy the invariant: unknown ids and deeds dropped, duplicates removed, then the newest
## strikes recanted until the floor holds. Every fix is logged with push_warning and kept in repair_log.
func repair() -> void:
	repair_log = PackedStringArray()
	if save_service == null:
		return
	var progress: PersistentProgress = _progress()
	var natures: PackedStringArray = config.nature_ids()
	var struck := PackedStringArray()
	for id in progress.struck_natures:
		if natures.has(id) and not struck.has(id):
			struck.append(id)
		else:
			_log("dropped unknown or non-nature id '%s' from struck_natures" % id)
	var floor_alive: int = config.effective_min_alive()
	while natures.size() - struck.size() < floor_alive and not struck.is_empty():
		_log("save had too few natures alive, recanted the newest strike '%s'" % struck[struck.size() - 1])
		struck.remove_at(struck.size() - 1)
	var armed := PackedStringArray()
	for id in progress.armed_trials:
		if natures.has(id) and not struck.has(id) and not armed.has(id):
			armed.append(id)
		else:
			_log("dropped '%s' from armed_trials" % id)
	var counts: Dictionary = {}
	for key: Variant in progress.strike_counts:
		if natures.has(String(key)):
			counts[String(key)] = progress.strike_counts[key]
		else:
			_log("dropped unknown id '%s' from strike_counts" % String(key))
	if repair_log.is_empty():
		return
	progress.struck_natures = struck
	progress.armed_trials = armed
	progress.strike_counts = counts
	_commit()
	_announce()


# --- Internals -----------------------------------------------------------------------------------------------

func _progress() -> PersistentProgress:
	return save_service.progress


func _strikes_in_run(run_index: int) -> int:
	if run_index != _cap_run:
		_cap_run = run_index
		# A strike already saved for this run (e.g. after a reload) counts against the cap.
		_cap_count = 1 if run_index > 0 and _progress().last_strike_run == run_index else 0
	return _cap_count


func _disarm(id: StringName) -> void:
	var progress: PersistentProgress = _progress()
	var at: int = progress.armed_trials.find(String(id))
	if at >= 0:
		progress.armed_trials.remove_at(at)


func _commit() -> void:
	save_service.commit_progress()


func _announce() -> void:
	SignalBus.origin_ledger_changed.emit(alive_natures(), _progress().struck_natures)


func _log(message: String) -> void:
	repair_log.append(message)
	push_warning("[OriginLedger] " + message)


func _on_trial_passed(id: StringName) -> void:
	if save_service != null and is_armed(id):
		request_strike(id, _progress().run_count)


func _on_claim_heard(id: StringName) -> void:
	if save_service != null:
		arm(id)
