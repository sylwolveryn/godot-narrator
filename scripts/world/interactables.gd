class_name Interactables
extends Node
## The interact control (task-072): a registry of Interactable objects and the owner of the interact action.
## Every physics step it picks the interactable in reach of the player (the nearest by footprint centre) and announces
## changes (SignalBus.interact_focus_changed; InteractHintView shows the hint glyph).
## Precedence: ONLY while something is in reach (a run is playing, the menu is closed, no teleport trip) does the
## interact action (Space, left click, gamepad X) belong to the object: the press is marked handled (the menu, the input
## discovery and the menu views never see it) and SignalBus.interact_hold_changed(true) tells the player not to walk
## toward the cursor while it is held. Otherwise the event passes untouched, so Space / click keep their old meanings
## (menu confirm while the menu is open, intro skip during the intro, pointer walking).
## The held object gets interact_pressed, interact_held every physics step and interact_released (or a cancel when the
## player leaves the reach, the menu opens, a trip starts or the run ends).
## Must sit after MenuController and InputDiscovery and before IntroSequence in the tree (later nodes see _input first:
## the intro still swallows its skip first, this node comes before the menu and the discovery).

@export var config: InteractConfig
@export var map_loader: MapLoader
@export var player: Node3D
## Read-only: interact only while a run is played.
@export var run_manager: RunManager

var _items: Array[Interactable] = []
var _focus: Interactable = null
var _held: Interactable = null
var _held_time: float = 0.0
var _menu_open: bool = false
var _teleporting: bool = false


func _ready() -> void:
	if config == null:
		config = InteractConfig.new()
	SignalBus.menu_opened.connect(func(_l: PackedStringArray, _s: int) -> void:
		_menu_open = true
		cancel())
	SignalBus.menu_closed.connect(func() -> void: _menu_open = false)
	SignalBus.teleport_started.connect(func(_f: Vector3, _c: Array[Vector3], _i: int, _d: float) -> void:
		_teleporting = true
		cancel())
	SignalBus.teleport_finished.connect(func() -> void: _teleporting = false)
	SignalBus.run_ended.connect(func(_c: StringName) -> void: cancel())
	SignalBus.run_started.connect(func(_i: int) -> void:
		_menu_open = false
		_teleporting = false
		cancel())


## Adds an interactable (no-op when already registered).
func register(item: Interactable) -> void:
	if item != null and not _items.has(item):
		_items.append(item)


func unregister(item: Interactable) -> void:
	if item == _held:
		cancel()
	_items.erase(item)
	if item == _focus:
		_set_focus(null)


## Removes every interactable (a new map).
func clear() -> void:
	cancel()
	_items.clear()
	_set_focus(null)


func count() -> int:
	return _items.size()


## The interactable in reach right now (null when none).
func focus() -> Interactable:
	return _focus


## The interactable whose interact is held (null when none).
func held() -> Interactable:
	return _held


func is_holding() -> bool:
	return _held != null


## Seconds the current interact has been held.
func held_seconds() -> float:
	return _held_time if _held != null else 0.0


## True when an interact press would go to an object now.
func can_interact() -> bool:
	return _focus != null and not _menu_open and not _teleporting and _playing()


## Starts an interact with the focused object. Returns false (and does nothing) when nothing is in reach or interacting
## is blocked.
func press() -> bool:
	if _held != null or not can_interact():
		return false
	_held = _focus
	_held_time = 0.0
	SignalBus.interact_hold_changed.emit(true)
	_held.interact_pressed()
	return true


## Ends the held interact normally.
func release() -> void:
	_end(false)


## Ends the held interact as cut short.
func cancel() -> void:
	_end(true)


func _end(cancelled: bool) -> void:
	if _held == null:
		return
	var item: Interactable = _held
	var time: float = _held_time
	_held = null
	_held_time = 0.0
	SignalBus.interact_hold_changed.emit(false)
	item.interact_released(time, cancelled)


func _input(event: InputEvent) -> void:
	if not InputMap.has_action(config.action) or not event.is_action(config.action):
		return
	if event.is_pressed():
		if event.is_echo():
			if _held != null:
				get_viewport().set_input_as_handled()
			return
		_refresh_focus()
		if press():
			get_viewport().set_input_as_handled()
	elif _held != null:
		get_viewport().set_input_as_handled()
		release()


func _physics_process(delta: float) -> void:
	_refresh_focus()
	if _held == null:
		return
	if not InputMap.has_action(config.action) or not Input.is_action_pressed(config.action):
		release()
		return
	if _held != _focus or not can_interact():
		cancel()
		return
	_held_time += delta
	_held.interact_held(delta, _held_time)


func _refresh_focus() -> void:
	if player == null or map_loader == null or not _playing():
		_set_focus(null)
		return
	var cell: Vector2i = map_loader.world_to_cell(player.global_position)
	var best: Interactable = null
	var best_d: float = INF
	for item in _items:
		if not item.in_reach(cell, config.default_reach):
			continue
		var d: float = map_loader.rect_to_world(item.footprint).distance_squared_to(player.global_position)
		if d < best_d:
			best_d = d
			best = item
	_set_focus(best)


func _set_focus(item: Interactable) -> void:
	if item == _focus:
		return
	_focus = item
	var centre: Vector3 = map_loader.rect_to_world(item.footprint) if item != null and map_loader != null else Vector3.ZERO
	SignalBus.interact_focus_changed.emit(item != null, centre)


func _playing() -> bool:
	return run_manager == null or run_manager.phase == RunManager.Phase.PLAYING
