class_name EntityProgression
extends Node
## Data layer of the multi-glyph entity (task-017). Unlocks it when the saved death count reaches
## EntityGrowthConfig.growth_unlock_deaths, plays the grow moment at the start of the first run after the unlock,
## and owns the active form (EntityForm.SINGLE / GROWN). It writes through SaveService and speaks through SignalBus
## (entity_unlocked, entity_grown, entity_form_changed); presentation only listens.
## Sits right after SaveService in the tree so the unlock check follows the death count update.

@export var config: EntityGrowthConfig
@export var save_service: SaveService
## Optional (task-090): the fit check of the many form runs a physics shape test at the player's place (and at the
## map's spawn for the grow moment at run start).
@export var player: Node3D
@export var map_loader: MapLoader
## Physics layers the grown body must not overlap (walls, dirt, props, pushable objects).
@export_flags_3d_physics var blocking_mask: int = 1
## Height of the body above the floor for the fit test (centre of the test cylinder) and its height.
@export var fit_test_height: float = 0.5
@export var fit_test_thickness: float = 0.6


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
	if not fits(form):
		# Task-090: the whole body has no room here.
		SignalBus.narration_event.emit(NarrationEvents.FORM_BLOCKED)
		return false
	save_service.set_entity_form(form)
	SignalBus.entity_form_changed.emit(form, true)
	return true


## Ground radius of the body in a form (task-090): the grown body is as wide as its formation; other forms 0 (their
## collision stays PlayerConfig.body_radius).
func body_radius(form: StringName) -> float:
	if form != EntityForm.GROWN or save_service == null or not config.whole_body:
		return 0.0
	return config.body_radius_for(save_service.progress.identity_glyph)


## True when the body of `form` has room where the player stands: no collider of blocking_mask within its radius.
## Forms without an own radius always fit; without a player there is nothing to test.
func fits(form: StringName, at: Variant = null) -> bool:
	var radius: float = body_radius(form)
	if radius <= 0.0 or player == null or not player.is_inside_tree():
		return true
	var where: Vector3 = at if at is Vector3 else player.global_position
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = fit_test_thickness
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = blocking_mask
	query.transform = Transform3D(Basis.IDENTITY, Vector3(where.x, fit_test_height, where.z))
	if player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]
	return player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


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
	# The grow moment waits for a run whose spawn has room for the whole body (task-090).
	var spawn: Variant = map_loader.spawn_position if map_loader != null else null
	if not save_service.progress.entity_grow_played and fits(EntityForm.GROWN, spawn):
		save_service.mark_entity_grow_played()
		save_service.set_entity_form(EntityForm.GROWN)
		SignalBus.entity_grown.emit()
		SignalBus.entity_form_changed.emit(EntityForm.GROWN, true)
	else:
		SignalBus.entity_form_changed.emit(current_form(), false)
