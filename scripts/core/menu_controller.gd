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
## Read-only: the Language list (task-065) shows its unlocked languages and their understanding. Without it the
## Language item is not offered.
@export var language: LanguageProgress

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
## True while the Language list is shown instead of the item list; its language ids (the back entry follows them).
var _language_shown: bool = false
var _language_ids: PackedStringArray = PackedStringArray()
## True while the Items list is shown (task-077); its entry count without the back entry.
var _items_shown: bool = false
var _items_count: int = 0
## Whether unseen items are offered (task-077); null until the first check.
var _new_pending: Variant = null
## Selection of the item list while a sub view is shown (restored on going back).
var _list_selected: int = 0
## True during a teleport trip: the menu does not open.
var _teleporting: bool = false


func _ready() -> void:
	if config == null:
		config = MenuConfig.new()
	if save_service == null:
		return
	save_service.progress_changed.connect(_check_unlock)
	save_service.progress_changed.connect(_update_new_items)
	SignalBus.run_started.connect(_on_run_started)
	SignalBus.run_ended.connect(_on_run_ended)
	SignalBus.menu_item_pointed.connect(_on_item_pointed)
	SignalBus.teleport_started.connect(_on_teleport_started)
	SignalBus.teleport_finished.connect(_on_teleport_finished)
	_check_unlock()
	# Entity and ledger answer their own _ready later in the tree: check the new items once everything is ready.
	_update_new_items.call_deferred()


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
		elif _language_shown:
			confirm_language()
		elif _items_shown:
			confirm_items()
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


## Opens the menu. Refused while it is locked, outside a run, during a teleport trip, or when no item is offered.
func open() -> bool:
	if _open or not is_unlocked() or _teleporting:
		return false
	if run_manager != null and run_manager.phase != RunManager.Phase.PLAYING:
		return false
	_offered = _available_items()
	if _offered.is_empty():
		return false
	_open = true
	_ledger_shown = false
	_language_shown = false
	_items_shown = false
	_selected = 0
	SignalBus.menu_opened.emit(current_labels(), _selected)
	if save_service != null:
		save_service.mark_menu_items_seen(_ids(_offered))
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	_ledger_shown = false
	_language_shown = false
	_items_shown = false
	SignalBus.menu_closed.emit()


func move_selection(step: int) -> void:
	if not _open or _offered.is_empty() or _ledger_shown:
		return
	_select(posmod(_selected + step, _page_size()))


## Confirms the selected item: a close item closes the menu, anything else is requested from the data layer.
func confirm() -> void:
	if not _open or _ledger_shown or _language_shown or _items_shown or _selected >= _offered.size():
		return
	var item: MenuItemDef = _offered[_selected]
	if item.action == MenuItemDef.ACTION_ITEMS:
		show_items()
		return
	if item.action == MenuItemDef.ACTION_REMEMBER:
		show_ledger()
		return
	if item.action == MenuItemDef.ACTION_LANGUAGE:
		show_languages()
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


## Leaves the ledger row or the Language list and shows the item list again with its item selected.
func back_to_list() -> void:
	if not _open or not (_ledger_shown or _language_shown or _items_shown):
		return
	if _language_shown or _items_shown:
		_language_shown = false
		_items_shown = false
		_selected = _list_selected
	_ledger_shown = false
	SignalBus.menu_opened.emit(current_labels(), _selected)


## True while the Language list is shown.
func is_language_shown() -> bool:
	return _language_shown


## Shows the Language list (task-065): asks the data layer first (it may unlock the next language), then lists one
## entry per unlocked language plus the back entry, with the selected language highlighted.
func show_languages() -> void:
	if not _open or _ledger_shown or _language_shown or language == null:
		return
	SignalBus.language_list_requested.emit()
	_list_selected = _selected
	_language_shown = true
	_language_ids = language.unlocked_languages().duplicate()
	_selected = maxi(0, _language_ids.find(String(language.selected_language())))
	SignalBus.menu_opened.emit(language_labels(), _selected)


## The Language list text: "English 37%" per unlocked language, then the back entry.
func language_labels() -> PackedStringArray:
	var labels := PackedStringArray()
	if language != null:
		labels = language.entry_labels()
	labels.append(config.language_back_label)
	return labels


## Confirms the selected Language entry: a language is requested from the data layer and the menu closes; the back
## entry returns to the item list.
func confirm_language() -> void:
	if not _open or not _language_shown:
		return
	if _selected >= _language_ids.size():
		back_to_list()
		return
	SignalBus.language_select_requested.emit(StringName(_language_ids[_selected]))
	close()


## True while the Items list is shown.
func is_items_shown() -> bool:
	return _items_shown


## Shows the Items list (task-077): what was consumed, one entry per kind with a label, then the back entry.
func show_items() -> void:
	if not _open or _ledger_shown or _language_shown or _items_shown:
		return
	_list_selected = _selected
	_items_shown = true
	var labels: PackedStringArray = items_labels()
	_items_count = labels.size() - 1
	_selected = 0
	SignalBus.menu_opened.emit(labels, _selected)


## The Items list text: "<label> <count>" per consumed kind (MenuConfig.items_labels order), then the back entry.
func items_labels() -> PackedStringArray:
	var labels := PackedStringArray()
	if save_service != null:
		for kind: StringName in config.items_labels:
			var count: int = save_service.consumed_count(kind)
			if count > 0:
				labels.append(config.items_format % [config.items_labels[kind], count])
	labels.append(config.items_back_label)
	return labels


## Confirms the selected Items entry: the back entry returns to the item list; a count entry does nothing.
func confirm_items() -> void:
	if not _open or not _items_shown:
		return
	if _selected >= _items_count:
		back_to_list()


## True while the menu offers an item the player has not seen in an open menu yet (task-077).
func has_new_items() -> bool:
	return _new_pending == true


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
		if item.action == MenuItemDef.ACTION_LANGUAGE and language == null:
			continue
		if item.requires_consumed and (save_service == null or not save_service.any_consumed()):
			continue
		out.append(item)
	return out


func _ids(items: Array[MenuItemDef]) -> PackedStringArray:
	var ids := PackedStringArray()
	for item in items:
		ids.append(String(item.id))
	return ids


## Re-checks whether unseen items are offered and tells the presentation when that changes. The first check after the
## menu is unlocked marks the items offered at that moment as seen (except announce_new items), so an old save does not
## pulse for items the player already knows.
func _update_new_items() -> void:
	var pending: bool = false
	if save_service != null and is_unlocked():
		var available: Array[MenuItemDef] = _available_items()
		if not save_service.progress.menu_seen_initialized:
			var known := PackedStringArray()
			for item in available:
				if not item.announce_new:
					known.append(String(item.id))
			# Emits progress_changed, which runs this check again with the list initialised.
			save_service.mark_menu_items_seen(known, true)
			return
		for item in available:
			if not save_service.progress.seen_menu_items.has(String(item.id)):
				pending = true
				break
	if pending != _new_pending:
		_new_pending = pending
		SignalBus.menu_new_items_changed.emit(pending)


func _check_unlock() -> void:
	if save_service == null or save_service.progress.menu_unlocked:
		return
	if save_service.progress.death_count >= config.menu_unlock_deaths:
		save_service.unlock_menu()
		SignalBus.menu_unlocked.emit()


func _on_item_pointed(index: int, activate: bool) -> void:
	if not _open or _ledger_shown or index < 0 or index >= _page_size():
		return
	_select(index)
	if activate:
		if _language_shown:
			confirm_language()
		elif _items_shown:
			confirm_items()
		else:
			confirm()


## Entries of the page shown right now (the item list, or the Language list with its back entry).
func _page_size() -> int:
	if _language_shown:
		return _language_ids.size() + 1
	if _items_shown:
		return _items_count + 1
	return _offered.size()


func _on_run_started(_run_index: int) -> void:
	_teleporting = false
	close()


## A teleport trip (task-068) closes the menu and keeps it shut until the trip is over.
func _on_teleport_started(_from: Vector3, _candidates: Array[Vector3], _chosen: int, _duration: float) -> void:
	_teleporting = true
	close()


func _on_teleport_finished() -> void:
	_teleporting = false


func _on_run_ended(_cause: StringName) -> void:
	close()
