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
## Layers (task-062): an event can have one line per layer (NarrationBeat.Layer: WORLD, OWN, NARRATOR). The event picks
## its earliest layer that has an eligible line; when that line starts, the eligible lines of the later layers of the
## same event are chained and start one after the other as soon as the previous one has dissolved (no silence gap).
## A death preempt drops the chain. Voice files (NarrationLibrary) play with narrator lines only.
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
## Optional (task-048): resolves the text and voice of a beat from the narration files (plugin overrides first) and
## records every triggered event. Without it a beat shows its own text and has no voice.
@export var library: NarrationLibrary

var state: State = State.FREE
var current: NarrationBeat
## Share of the current line's letters that stay unsettled (0 = a normal line). Set before beat_started is emitted.
var current_doubt: float = 0.0
## Text and voice of the current beat (resolved through the library). Set before beat_started is emitted.
var current_text: String = ""
var current_voice: AudioStream
## Understanding (0..1) of the narration language, for OWN lines (NarrationLibrary.understanding()). Set before beat_started.
var current_understanding: float = 1.0
## Latest understanding of the selected language from SignalBus.language_understanding_changed (task-065); before the
## first signal the library's value (DB player_language) is used.
var _understanding: float = 1.0
var _has_understanding: bool = false
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
## Later-layer lines of the event on screen, in layer order (task-062).
var _chain: Array[NarrationBeat] = []
var _heard: Dictionary[String, bool] = {}
## Candidates collected this frame: Array of [NarrationBeat, int priority].
var _candidates: Array = []
var _run_active: bool = false
var _run_time: float = 0.0
var _moving: bool = false
var _still_time: float = 0.0
## Idle steps fired this run (0 = none, 1 = short, 2 = mid, 3 = long).
var _idle_step: int = 0
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
	SignalBus.language_understanding_changed.connect(_on_language_understanding_changed)


func _process(delta: float) -> void:
	advance(delta)


## Advances every timer by `delta` seconds, then decides what to show. Called by _process;
## tests call it directly for deterministic time.
func advance(delta: float) -> void:
	_clock += delta
	if _run_active:
		_run_time += delta
		if not _moving:
			_still_time += delta
			_check_idle()
		_check_time_beats()
	_tick_state(delta)
	if queued != null and _clock - _queued_at > config.queue_ttl_seconds and not config.ttl_exempt_events.has(queued.event):
		queued = null
	# The next layer of the event on screen follows as soon as the previous line has dissolved.
	if not _chain.is_empty() and (state == State.FREE or state == State.GAP):
		_start(_chain.pop_front(), true)
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
## A beat with an event_param only answers an event carrying that parameter. With no beat of its own the event
## falls back to NarratorConfig.event_fallbacks (e.g. TRANSFORMED_TO_ONE -> TRANSFORMED).
func pick_for_event(event: StringName, param: StringName = &"") -> NarrationBeat:
	var beat: NarrationBeat = _pick_exact(event, param)
	var hops: int = 0
	while beat == null and config.event_fallbacks.has(event) and hops < config.event_fallbacks.size():
		event = config.event_fallbacks[event]
		beat = _pick_exact(event, param)
		hops += 1
	return beat


## Best eligible beat of an event; `layer` >= 0 restricts it to that layer, otherwise the earliest layer wins.
func _pick_exact(event: StringName, param: StringName, layer: int = -1) -> NarrationBeat:
	var survivors: PackedStringArray = floor_survivors()
	var best: NarrationBeat
	for beat: NarrationBeat in config.beats:
		if beat.trigger != NarrationBeat.Trigger.EVENT or beat.event != event:
			continue
		if layer >= 0 and beat.layer != layer:
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
	if a.layer != b.layer:
		return a.layer < b.layer
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
	if library != null:
		library.note_triggered(event)
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
	if beat == queued or _reactive.has(beat) or _chain.has(beat):
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
	_chain.clear()
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


## Starts a beat. Unless it is itself a chained line, the later layers of its event are chained behind it.
func _start(beat: NarrationBeat, chained: bool = false) -> void:
	current = beat
	state = State.SHOWING
	_timer = config.morph_in_seconds + config.beat_hold_seconds
	current_doubt = doubt_fraction(beat)
	current_text = library.line_for(beat) if library != null else beat.text
	if _has_understanding:
		current_understanding = _understanding
	else:
		current_understanding = library.understanding() if library != null else 1.0
	current_voice = null
	if library != null and beat.layer == NarrationBeat.Layer.NARRATOR:
		current_voice = library.audio_for(NarrationLibrary.event_of(beat))
	if not chained:
		_chain = layer_followers(beat)
	if beat.once:
		_heard[beat.id] = true
		SignalBus.beat_heard.emit(beat.id)
	var claimed: StringName = claimed_nature(beat)
	if claimed != &"":
		SignalBus.origin_claim_heard.emit(claimed)
	beat_started.emit(beat)


## The eligible lines of the later layers of a beat's event, in layer order (empty for TIME beats).
func layer_followers(beat: NarrationBeat) -> Array[NarrationBeat]:
	var out: Array[NarrationBeat] = []
	if beat.trigger != NarrationBeat.Trigger.EVENT:
		return out
	for layer in range(beat.layer + 1, NarrationBeat.Layer.size()):
		var next: NarrationBeat = _pick_exact(beat.event, beat.event_param, layer)
		if next != null and next != beat:
			out.append(next)
	return out


## The lines still chained behind the one on screen (tests, tools).
func chained() -> Array[NarrationBeat]:
	return _chain


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
	_idle_step = 0
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
	var event: StringName = config.death_events.get(cause, config.default_death_event)
	if event != &"":
		_offer(event)


func _on_origin_struck(id: StringName) -> void:
	_offer(NarrationEvents.ORIGIN_STRUCK, id)


func _on_origin_recanted(id: StringName) -> void:
	_offer(NarrationEvents.ORIGIN_RECANTED, id)


## Only a chosen switch counts (animate = true); the restore at run start is not a choice. The specific direction is
## offered; beats on TRANSFORMED answer it through the fallback.
func _on_entity_form_changed(form: StringName, animate: bool) -> void:
	if animate:
		trigger_event(NarrationEvents.TRANSFORMED_TO_ONE if form == EntityForm.SINGLE else NarrationEvents.TRANSFORMED_TO_MANY)


## Fires the next idle step once the stillness reached its threshold (each step once per run).
func _check_idle() -> void:
	var thresholds: Array[float] = [config.idle_seconds, config.idle_mid_seconds, config.idle_long_seconds]
	var events: Array[StringName] = [NarrationEvents.IDLE_FOR_SHORT, NarrationEvents.IDLE_FOR_MID, NarrationEvents.IDLE_FOR_LONG]
	if _idle_step < thresholds.size() and _still_time >= thresholds[_idle_step]:
		trigger_event(events[_idle_step])
		_idle_step += 1


func _on_language_understanding_changed(_language: StringName, understanding: float) -> void:
	_understanding = clampf(understanding, 0.0, 1.0)
	_has_understanding = true


func _on_player_motion_changed(moving: bool) -> void:
	_moving = moving
	if not moving:
		_still_time = 0.0


func _on_erosion_changed(amount: float, _tint: Color) -> void:
	if _erosion_high_fired or amount < config.erosion_high_threshold:
		return
	_erosion_high_fired = true
	trigger_event(NarrationEvents.EROSION_HIGH)
