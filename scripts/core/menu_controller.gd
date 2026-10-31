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

var _open: bool = false
var _selected: int = 0
## The offered items while open, in display order.
var _offered: Array[MenuItemDef] = []


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
	if event.is_action_pressed(config.action_up):
		move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(config.action_down):
		move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(config.action_confirm):
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
	_selected = 0
	SignalBus.menu_opened.emit(current_labels(), _selected)
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	SignalBus.menu_closed.emit()


func move_selection(step: int) -> void:
	if not _open or _offered.is_empty():
		return
	_select(posmod(_selected + step, _offered.size()))


## Confirms the selected item: a close item closes the menu, anything else is requested from the data layer.
func confirm() -> void:
	if not _open or _selected >= _offered.size():
		return
	var item: MenuItemDef = _offered[_selected]
	if item.action != MenuItemDef.ACTION_CLOSE:
		SignalBus.menu_action_requested.emit(item.action)
	if item.closes_menu:
		close()


func _select(index: int) -> void:
	if index == _selected:
		return
	_selected = index
	SignalBus.menu_selection_changed.emit(_selected)


func _available_items() -> Array[MenuItemDef]:
	var out: Array[MenuItemDef] = []
	var entity_ready: bool = entity != null and entity.is_unlocked()
	for item in config.items:
		if item != null and (entity_ready or not item.requires_entity):
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
