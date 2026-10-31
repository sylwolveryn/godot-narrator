class_name EntityProgression
extends Node
## Data layer of the multi-glyph entity (task-017). Unlocks it when the saved death count reaches
## EntityGrowthConfig.growth_unlock_deaths, plays the grow moment at the start of the first run after the unlock,
## and owns the active form (EntityForm.SINGLE / GROWN). It writes through SaveService and speaks through SignalBus
## (entity_unlocked, entity_grown, entity_form_changed); presentation only listens.
## Sits right after SaveService in the tree so the unlock check follows the death count update.

@export var config: EntityGrowthConfig
@export var save_service: SaveService


func _ready() -> void:
	if config == null:
		config = EntityGrowthConfig.new()
	if save_service == null:
		return
	save_service.progress_changed.connect(_check_unlock)
	SignalBus.run_started.connect(_on_run_started)
	SignalBus.menu_action_requested.connect(_on_menu_action)
	_check_unlock()


## True once the entity has been unlocked (persisted).
func is_unlocked() -> bool:
	return save_service != null and save_service.progress.entity_unlocked


## The active form; SINGLE until the entity is unlocked.
func current_form() -> StringName:
	if not is_unlocked():
		return EntityForm.SINGLE
	return StringName(save_service.progress.entity_form)


## Switches the active form (the in-world menu, task-018, calls this). Returns false before the unlock or for an
## unknown form. Listeners get entity_form_changed with animate = true.
func set_form(form: StringName) -> bool:
	if not is_unlocked() or not EntityForm.is_valid(form):
		return false
	if form == current_form():
		return true
	save_service.set_entity_form(form)
	SignalBus.entity_form_changed.emit(form, true)
	return true


func _check_unlock() -> void:
	if save_service == null or save_service.progress.entity_unlocked:
		return
	if save_service.progress.death_count >= config.growth_unlock_deaths:
		save_service.unlock_entity()
		SignalBus.entity_unlocked.emit()


## The in-world menu (task-018) asks for the other form; presentation only requested it.
func _on_menu_action(action: StringName) -> void:
	if action != MenuItemDef.ACTION_SWITCH_FORM:
		return
	set_form(EntityForm.SINGLE if current_form() == EntityForm.GROWN else EntityForm.GROWN)


func _on_run_started(_run_index: int) -> void:
	if not is_unlocked():
		return
	if not save_service.progress.entity_grow_played:
		save_service.mark_entity_grow_played()
		save_service.set_entity_form(EntityForm.GROWN)
		SignalBus.entity_grown.emit()
		SignalBus.entity_form_changed.emit(EntityForm.GROWN, true)
	else:
		SignalBus.entity_form_changed.emit(current_form(), false)
