class_name Narrator
extends Node
## Picks and schedules narration beats. Logic only: it listens to SignalBus events and emits
## local signals the overlay and the sfx player listen to (signals travel up, never down).
##
## One beat is on screen at a time: SHOWING (morph-in + hold) -> DISSOLVING (morph-out) -> GAP
## (silence) -> FREE. The queue holds one beat with a time to live; a newer beat of a higher
## priority class replaces it. Death beats preempt. Triggers arriving in the same frame compete
## by class priority. A beat counts as heard (SignalBus.beat_heard) only when it starts displaying.
##
## Origin system (task-042): a CLAIM beat that starts displaying (and a RECANT beat, which restates the claim)
## emits SignalBus.origin_claim_heard(nature); the ledger arms the trial. BROKEN / RECANT beats answer
## origin_struck / origin_recanted (event_param = nature) through the reactive FIFO (NarratorConfig.reactive_events),
## so the queue never drops them. A beat whose supports are all struck plays as a doubt line (current_doubt > 0),
## and at the floor the ladder prefers beats that support both surviving natures.
##
## Must sit after SaveService and OriginLedger and before Player/MapReveal in the tree: signal handlers run in
## tree order, and run_count must be updated and run_started seen before the first reveals.

## A beat starts displaying (morph in, play its sfx).
signal beat_started(beat: NarrationBeat)
## The current beat should dissolve. `fast` = preempted by a death beat.
signal beat_dissolving(fast: bool)

enum State { FREE, SHOWING, DISSOLVING, GAP, PREEMPTING }

@export var config: NarratorConfig
## Read-only source of run_count, death_count and heard_beats.
@export var save_service: SaveService
## Read-only: the rule-out state (claim eligibility, doubt, floor tie-break) and its config. Optional.
@export var ledger: OriginLedger

var state: State = State.FREE
var current: NarrationBeat
## Share of the current line's letters that stay unsettled (0 = a normal line). Set before beat_started is emitted.
var current_doubt: float = 0.0
var queued: NarrationBeat
## Run bookkeeping; refreshed on every run_started.
var run_count: int = 1
var death_count: int = 0

var _clock: float = 0.0
var _timer: float = 0.0
var _queued_at: float = 0.0
var _queued_priority: int = -1
## A TTL-exempt beat displaced from the queue by a higher class; it re-queues when the slot frees.
var _parked: NarrationBeat
var _next_after_preempt: NarrationBeat
## Beats of reactive events, in the order they were offered.
var _reactive: Array[NarrationBeat] = []
var _heard: Dictionary[String, bool] = {}
## Candidates collected this frame: Array of [NarrationBeat, int priority].
var _candidates: Array = []
var _run_active: bool = false
var _run_time: float = 0.0
var _moving: bool = false
var _still_time: float = 0.0
var _idle_fired: bool = false
var _erosion_high_fired: bool = false
var _time_fired: Dictionary[String, bool] = {}


func _ready() -> void:
	if config == null:
		config = NarratorConfig.new()
	SignalBus.run_started.connect(_on_run_started)
	SignalBus.run_ended.connect(_on_run_ended)
	SignalBus.narration_event.connect(trigger_event)
	SignalBus.player_motion_changed.connect(_on_player_motion_changed)
	SignalBus.erosion_changed.connect(_on_erosion_changed)
	SignalBus.origin_struck.connect(_on_origin_struck)
	SignalBus.origin_recanted.connect(_on_origin_recanted)
	SignalBus.entity_form_changed.connect(_on_entity_form_changed)


func _process(delta: float) -> void:
	advance(delta)


## Advances every timer by `delta` seconds, then decides what to show. Called by _process;
## tests call it directly for deterministic time.
func advance(delta: float) -> void:
	_clock += delta
	if _run_active:
		_run_time += delta
		if not _moving and not _idle_fired:
			_still_time += delta
			if _still_time >= config.idle_seconds:
				_idle_fired = true
				trigger_event(NarrationEvents.IDLE)
		_check_time_beats()
	_tick_state(delta)
	if queued != null and _clock - _queued_at > config.queue_ttl_seconds and not config.ttl_exempt_events.has(queued.event):
		queued = null
	# Reactive beats start as soon as nothing is showing; the silence gap does not hold them back.
	if not _reactive.is_empty() and (state == State.FREE or state == State.GAP):
		_start(_reactive.pop_front())
	_resolve_candidates()
	if state == State.FREE and queued != null:
		var next: NarrationBeat = queued
		queued = null
		_start(next)
	if queued == null and _parked != null:
		queued = _parked
		_parked = null
		_queued_at = _clock


## True when `beat` may play for the given counters (trigger matching is the caller's job).
func is_eligible(beat: NarrationBeat, runs: int, deaths: int) -> bool:
	if runs < beat.min_run:
		return false
	if beat.max_run >= 0 and runs > beat.max_run:
		return false
	if deaths < beat.min_deaths:
		return false
	if beat.once and is_heard(beat.id):
		return false
	if beat.role == NarrationBeat.Role.CLAIM and ledger != null:
		# Alive, unarmed and not dormant; a nature without a claimable trial never gets its claim played.
		return not beat.supports.is_empty() and ledger.is_claimable(StringName(beat.supports[0]))
	return true


func is_heard(beat_id: String) -> bool:
	if _heard.has(beat_id):
		return true
	return save_service != null and save_service.progress.heard_beats.has(beat_id)


## The beat an event would play right now: lowest min_run first. In a tie the beat that supports both surviving
## natures wins when the ledger is at its floor (OriginConfig.tie_prefer_dual_support), then table order.
## A beat with an event_param only answers an event carrying that parameter.
func pick_for_event(event: StringName, param: StringName = &"") -> NarrationBeat:
	var survivors: PackedStringArray = floor_survivors()
	var best: NarrationBeat
	for beat: NarrationBeat in config.beats:
		if beat.trigger != NarrationBeat.Trigger.EVENT or beat.event != event:
			continue
		if beat.event_param != &"" and beat.event_param != param:
			continue
		if not is_eligible(beat, run_count, death_count) or _is_pending(beat):
			continue
		if best == null or _ranks_before(beat, best, survivors):
			best = beat
	return best


## The two surviving natures when the ledger is at its floor and the tie-break is on, else empty.
func floor_survivors() -> PackedStringArray:
	if ledger == null or ledger.config == null or not ledger.config.tie_prefer_dual_support:
		return PackedStringArray()
	var alive: PackedStringArray = ledger.alive_natures()
	if alive.size() > ledger.config.effective_min_alive():
		return PackedStringArray()
	return alive


## True when `beat` supports every one of `natures` (false for an empty list).
func supports_all(beat: NarrationBeat, natures: PackedStringArray) -> bool:
	if natures.is_empty():
		return false
	for id in natures:
		if not beat.supports.has(id):
			return false
	return true


func _ranks_before(a: NarrationBeat, b: NarrationBeat, survivors: PackedStringArray) -> bool:
	if a.min_run != b.min_run:
		return a.min_run < b.min_run
	var dual_a: bool = supports_all(a, survivors)
	if dual_a != supports_all(b, survivors):
		return dual_a
	return a.order < b.order


## Share of letters left unsettled when `beat` plays: OriginConfig.doubt_scramble when it supports something and
## every hypothesis it supports is struck (deeds are never struck, so a beat that also supports a deed is no doubt
## line), else 0.
func doubt_fraction(beat: NarrationBeat) -> float:
	if ledger == null or ledger.config == null or beat.supports.is_empty():
		return 0.0
	for id in beat.supports:
		# Struck = a nature that is not alive (deeds are not natures and are never struck).
		if not ledger.is_nature(StringName(id)) or ledger.is_alive(StringName(id)):
			return 0.0
	return ledger.config.doubt_scramble


## Offers an event to the narrator. Non-death events are ignored outside a run; the beat is
## decided at the next advance(), together with any other trigger of the same frame.
## `param` is the event parameter (the nature id of origin_struck / origin_recanted).
func trigger_event(event: StringName, param: StringName = &"") -> void:
	_offer(event, param)


## Priority class of an event.
func priority_of(event: StringName) -> int:
	return config.event_priority.get(event, 0)


func _offer(event: StringName, param: StringName = &"") -> void:
	var is_death: bool = priority_of(event) >= config.preempt_priority
	var reactive: bool = config.reactive_events.has(event)
	if not _run_active and not is_death and not reactive:
		return
	var beat: NarrationBeat = pick_for_event(event, param)
	if beat == null:
		return
	if reactive:
		_reactive.append(beat)
	else:
		_candidates.append([beat, priority_of(event)])


func _check_time_beats() -> void:
	for beat: NarrationBeat in config.beats:
		if beat.trigger != NarrationBeat.Trigger.TIME or _time_fired.has(beat.id) or _run_time < beat.delay:
			continue
		if not is_eligible(beat, run_count, death_count) or _is_pending(beat):
			continue
		_time_fired[beat.id] = true
		_candidates.append([beat, priority_of(NarrationEvents.TIME)])


## True when the beat is already a candidate, queued, or on screen.
func _is_pending(beat: NarrationBeat) -> bool:
	for candidate: Array in _candidates:
		if candidate[0] == beat:
			return true
	if beat == queued or _reactive.has(beat):
		return true
	return beat == current and (state == State.SHOWING or state == State.DISSOLVING or state == State.PREEMPTING)


## Picks the best candidate of this frame (highest class, then first offered) and routes it.
func _resolve_candidates() -> void:
	if _candidates.is_empty():
		return
	var best: Array = _candidates[0]
	for candidate: Array in _candidates:
		if candidate[1] > best[1]:
			best = candidate
	_candidates.clear()
	var beat: NarrationBeat = best[0]
	var priority: int = best[1]
	if priority >= config.preempt_priority:
		_preempt(beat)
	elif state == State.FREE and queued == null:
		_start(beat)
	elif queued == null or priority > _queued_priority:
		if queued != null and config.ttl_exempt_events.has(queued.event):
			_parked = queued
		queued = beat
		_queued_priority = priority
		_queued_at = _clock


func _preempt(beat: NarrationBeat) -> void:
	queued = null
	match state:
		State.FREE, State.GAP:
			_start(beat)
		State.PREEMPTING:
			_next_after_preempt = beat
		_:
			state = State.PREEMPTING
			_timer = config.preempt_dissolve_seconds
			_next_after_preempt = beat
			beat_dissolving.emit(true)


func _start(beat: NarrationBeat) -> void:
	current = beat
	state = State.SHOWING
	_timer = config.morph_in_seconds + config.beat_hold_seconds
	current_doubt = doubt_fraction(beat)
	if beat.once:
		_heard[beat.id] = true
		SignalBus.beat_heard.emit(beat.id)
	var claimed: StringName = claimed_nature(beat)
	if claimed != &"":
		SignalBus.origin_claim_heard.emit(claimed)
	beat_started.emit(beat)


## The nature whose trial a beat arms when heard: a CLAIM beat's nature, or the nature a RECANT beat takes back
## (the recant restates the claim). Empty for every other beat.
func claimed_nature(beat: NarrationBeat) -> StringName:
	match beat.role:
		NarrationBeat.Role.CLAIM:
			return StringName(beat.supports[0]) if not beat.supports.is_empty() else &""
		NarrationBeat.Role.RECANT:
			return beat.event_param
	return &""


func _tick_state(delta: float) -> void:
	if state == State.FREE:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	match state:
		State.SHOWING:
			state = State.DISSOLVING
			_timer = config.morph_out_seconds
			beat_dissolving.emit(false)
		State.DISSOLVING:
			state = State.GAP
			_timer = config.beat_gap_seconds
		State.GAP:
			state = State.FREE
		State.PREEMPTING:
			var next: NarrationBeat = _next_after_preempt
			_next_after_preempt = null
			_start(next)


func _on_run_started(run_index: int) -> void:
	if save_service != null:
		run_count = save_service.progress.run_count
		death_count = save_service.progress.death_count
	else:
		run_count = run_index + 1
	_parked = null
	# A new run cuts the silence after the previous beat (a beat still on screen finishes normally).
	if state == State.GAP:
		state = State.FREE
	_run_active = true
	_run_time = 0.0
	_moving = false
	_still_time = 0.0
	_idle_fired = false
	_erosion_high_fired = false
	_time_fired.clear()
	_candidates.clear()
	queued = null
	_offer(NarrationEvents.RUN_STARTED)


func _on_run_ended(cause: StringName) -> void:
	_run_active = false
	queued = null
	_parked = null
	_candidates = _candidates.filter(func(c: Array) -> bool: return c[1] >= config.preempt_priority)
	if save_service != null:
		death_count = save_service.progress.death_count
	else:
		death_count += 1
	var event: StringName = config.death_events.get(cause, &"")
	if event != &"":
		_offer(event)


func _on_origin_struck(id: StringName) -> void:
	_offer(NarrationEvents.ORIGIN_STRUCK, id)


func _on_origin_recanted(id: StringName) -> void:
	_offer(NarrationEvents.ORIGIN_RECANTED, id)


## Only a chosen switch counts (animate = true); the restore at run start is not a choice.
func _on_entity_form_changed(_form: StringName, animate: bool) -> void:
	if animate:
		trigger_event(NarrationEvents.ENTITY_FORM_CHANGED)


func _on_player_motion_changed(moving: bool) -> void:
	_moving = moving
	if not moving:
		_still_time = 0.0


func _on_erosion_changed(amount: float, _tint: Color) -> void:
	if _erosion_high_fired or amount < config.erosion_high_threshold:
		return
	_erosion_high_fired = true
	trigger_event(NarrationEvents.EROSION_HIGH)
