class_name MenuController
extends Node
## Logic of the in-world menu (task-018). Unlocks the menu when the saved death count reaches
## MenuConfig.menu_unlock_deaths (persisted through SaveService), opens and closes it on the menu_toggle action,
## moves the selection with menu_up / menu_down and confirms with menu_confirm (or the pointer, reported by the
## presentation on SignalBus.menu_item_pointed). It NEVER pauses anything: the world, the hazards and the narration
## keep running while it is open; only the player's movement input is taken over (Player listens to menu_opened).
## It speaks through SignalBus (menu_unlocked / opened / closed / selection_changed / action_requested); the
## presentation (MenuGlyphView) only listens, and the data layer (EntityProgression) applies the requested actions.
## Sits right after EntityProgression in the tree.

@export var config: MenuConfig
@export var save_service: SaveService
## Read-only: whether the entity is unlocked and which form is active (decides which items are offered and their text).
@export var entity: EntityProgression
## Read-only: the menu only opens while a run is being played.
@export var run_manager: RunManager
## Read-only: decides whether "remember" is offered and what the ledger row shows (task-043).
@export var ledger: OriginLedger

## Presentation state of one hypothesis in the ledger row.
const LEDGER_ALIVE: StringName = &"alive"
const LEDGER_STRUCK: StringName = &"struck"
const LEDGER_RECANTED: StringName = &"recanted"
const LEDGER_DEED: StringName = &"deed"

var _open: bool = false
var _selected: int = 0
## The offered items while open, in display order.
var _offered: Array[MenuItemDef] = []
## True while the ledger row is shown instead of the list.
var _ledger_shown: bool = false


func _ready() -> void:
	if config == null:
		config = MenuConfig.new()
	if save_service == null:
		return
	save_service.progress_changed.connect(_check_unlock)
	SignalBus.run_started.connect(_on_run_started)
	SignalBus.run_ended.connect(_on_run_ended)
	SignalBus.menu_item_pointed.connect(_on_item_pointed)
	_check_unlock()


func _input(event: InputEvent) -> void:
	# Alt+Enter is the fullscreen toggle, not a confirm.
	if event is InputEventKey and (event as InputEventKey).alt_pressed:
		return
	if event.is_action_pressed(config.action_toggle):
		if toggle():
			get_viewport().set_input_as_handled()
		return
	if not _open:
		return
	if _ledger_shown:
		if event.is_action_pressed(config.action_up) or event.is_action_pressed(config.action_down):
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(config.action_up):
		move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(config.action_down):
		move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(config.action_confirm):
		if _ledger_shown:
			back_to_list()
		else:
			confirm()
		get_viewport().set_input_as_handled()


## True once the menu has been unlocked (persisted).
func is_unlocked() -> bool:
	return save_service != null and save_service.progress.menu_unlocked


func is_open() -> bool:
	return _open


func selected_index() -> int:
	return _selected


## The text of the items offered right now (what an open menu would show).
func current_labels() -> PackedStringArray:
	var form: StringName = EntityForm.SINGLE if entity == null else entity.current_form()
	var labels := PackedStringArray()
	for item in _available_items():
		labels.append(item.text_for(form))
	return labels


## Opens when closed, closes when open. Returns false when nothing happened.
func toggle() -> bool:
	if _open:
		close()
		return true
	return open()


## Opens the menu. Refused while it is locked, outside a run, or when no item is offered.
func open() -> bool:
	if _open or not is_unlocked():
		return false
	if run_manager != null and run_manager.phase != RunManager.Phase.PLAYING:
		return false
	_offered = _available_items()
	if _offered.is_empty():
		return false
	_open = true
	_ledger_shown = false
	_selected = 0
	SignalBus.menu_opened.emit(current_labels(), _selected)
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	_ledger_shown = false
	SignalBus.menu_closed.emit()


func move_selection(step: int) -> void:
	if not _open or _offered.is_empty() or _ledger_shown:
		return
	_select(posmod(_selected + step, _offered.size()))


## Confirms the selected item: a close item closes the menu, anything else is requested from the data layer.
func confirm() -> void:
	if not _open or _ledger_shown or _selected >= _offered.size():
		return
	var item: MenuItemDef = _offered[_selected]
	if item.action == MenuItemDef.ACTION_REMEMBER:
		show_ledger()
		return
	if item.action != MenuItemDef.ACTION_CLOSE:
		SignalBus.menu_action_requested.emit(item.action)
	if item.closes_menu:
		close()


## True while the ledger row is shown.
func is_ledger_shown() -> bool:
	return _ledger_shown


## Shows the ledger row (the menu stays open, nothing is paused). Refused when the menu is closed.
func show_ledger() -> void:
	if not _open or _ledger_shown:
		return
	_ledger_shown = true
	SignalBus.menu_ledger_shown.emit(ledger_entries())


## Leaves the ledger row and shows the list again with "remember" selected.
func back_to_list() -> void:
	if not _open or not _ledger_shown:
		return
	_ledger_shown = false
	SignalBus.menu_opened.emit(current_labels(), _selected)


## One entry per hypothesis, in the ledger's order, read from the ledger's public API.
func ledger_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if ledger == null or ledger.config == null:
		return out
	for h in ledger.config.hypotheses:
		if h == null:
			continue
		var state: StringName = LEDGER_DEED
		if h.is_nature():
			if not ledger.is_alive(h.id):
				state = LEDGER_STRUCK
			elif ledger.strike_count(h.id) > 0:
				state = LEDGER_RECANTED
			else:
				state = LEDGER_ALIVE
		out.append({"id": h.id, "sigil": h.sigil, "state": state})
	return out


func _select(index: int) -> void:
	if index == _selected:
		return
	_selected = index
	SignalBus.menu_selection_changed.emit(_selected)


func _available_items() -> Array[MenuItemDef]:
	var out: Array[MenuItemDef] = []
	var entity_ready: bool = entity != null and entity.is_unlocked()
	for item in config.items:
		if item == null or (item.requires_entity and not entity_ready):
			continue
		if item.requires_claim and (ledger == null or not ledger.any_claim_heard()):
			continue
		out.append(item)
	return out


func _check_unlock() -> void:
	if save_service == null or save_service.progress.menu_unlocked:
		return
	if save_service.progress.death_count >= config.menu_unlock_deaths:
		save_service.unlock_menu()
		SignalBus.menu_unlocked.emit()


func _on_item_pointed(index: int, activate: bool) -> void:
	if not _open or index < 0 or index >= _offered.size():
		return
	_select(index)
	if activate:
		confirm()


func _on_run_started(_run_index: int) -> void:
	close()


func _on_run_ended(_cause: StringName) -> void:
	close()
