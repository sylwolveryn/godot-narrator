class_name Player
extends CharacterBody3D
## The player body. Placed at the map's spawn cell on every run_started. It has no mesh:
## its visible identity is a glyph drawn on the overlay layer (decision-001).
## Moves top-down on the XZ plane once an input scheme has been discovered.

## Emitted when the identity glyph is (re)assigned. The overlay listens.
signal identity_changed(glyph: String)

@export var config: PlayerConfig
@export var map_loader: MapLoader
@export var save_service: SaveService
## Read-only source of the run phase and the discovered input scheme.
@export var run_manager: RunManager
## Source of the active camera view; keyboard and gamepad input is rotated by its current yaw so
## "up" means up on screen, also after the player rotates the camera.
@export var camera_rig: CameraRig
## Optional (task-055): source of the movement profiles (DB table movement_profile, one row per entity form plus
## "default"). Without it, or before it is read, PlayerConfig's movement values are used.
@export var database: GameDatabase

var identity_glyph: String = ""
## Movement in effect (from the active form's profile). Read-only for others.
var max_speed: float = 0.0
var acceleration: float = 0.0
var deceleration: float = 0.0
## Sprint multipliers of the active profile (task-063). Read-only for others.
var sprint_speed_mult: float = 1.0
var sprint_accel_mult: float = 1.0
var sprint_decel_mult: float = 1.0
## The active entity form (EntityForm id; empty until the first entity_form_changed).
var form: StringName = &""
## Direction the input asks for this physics step on the ground (length 0..1, zero when idle). Differs from the
## velocity when the body is blocked; PushableObjects reads it to know what is being pushed.
var move_intent: Vector3 = Vector3.ZERO

var _ground: Plane = Plane(Vector3.UP, 0.0)
var _moving: bool = false
var _moved_this_run: bool = false
var _menu_open: bool = false
## Ground offset from the player to the cursor while the pointer is held, else null.
var _pointer_offset: Variant = null
## Map cell the player stood in last physics step (steps are counted when it changes).
var _cell: Vector2i = Vector2i(-1000000, -1000000)
## True while the body pushes into an obstacle; seconds until another bump may be announced.
var _touching: bool = false
var _hit_cooldown: float = 0.0
## Sprint: unlocked for this run (decided at spawn from the death count); held this step; still gliding after one.
var _sprint_available: bool = false
var _sprinting: bool = false
var _sprint_glide: bool = false


func _ready() -> void:
	if config == null:
		config = PlayerConfig.new()
	if config.identity_pool == null:
		config.identity_pool = IdentityPool.new()
	# Top-down: no floor or gravity, the body slides on the XZ plane.
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	apply_movement_profile()
	SignalBus.entity_form_changed.connect(_on_entity_form_changed)
	if database != null:
		database.tables_loaded.connect(func(_tables: Dictionary) -> void: apply_movement_profile())
		apply_movement_profile()
	SignalBus.run_started.connect(_on_run_started)
	SignalBus.menu_opened.connect(_on_menu_opened)
	SignalBus.menu_closed.connect(_on_menu_closed)


func _physics_process(delta: float) -> void:
	var direction: Vector3 = _wanted_direction()
	_sprinting = _sprint_available and direction != Vector3.ZERO and Input.is_action_pressed(config.action_sprint)
	var top_speed: float = max_speed * (sprint_speed_mult if _sprinting else 1.0)
	var wanted: Vector3 = direction * top_speed
	move_intent = direction
	_update_sprint_glide(direction)
	var rate: float
	if wanted != Vector3.ZERO:
		rate = acceleration * (sprint_accel_mult if _sprinting else 1.0)
	else:
		rate = deceleration * (sprint_decel_mult if _sprint_glide else 1.0)
	velocity = velocity.move_toward(wanted, rate * delta)
	velocity.y = 0.0
	_limit_to_cursor(delta)
	move_and_slide()
	global_position.y = 0.0
	_announce_motion()
	_announce_step()
	_announce_contact(delta)


func _on_run_started(_run_index: int) -> void:
	spawn()


## True while sprint is held, unlocked and there is movement input (presentation and tests read it).
func is_sprinting() -> bool:
	return _sprinting


## True when sprint is unlocked for the current run (decided at spawn).
func is_sprint_available() -> bool:
	return _sprint_available


## After a sprint the stop glides (lower deceleration) until the body has nearly stopped. Walking on without sprint
## ends the glide once the speed has eased back down to the normal top speed.
func _update_sprint_glide(direction: Vector3) -> void:
	var speed: float = velocity.length()
	if _sprinting:
		_sprint_glide = true
	elif speed <= config.sprint_glide_end_speed or (direction != Vector3.ZERO and speed <= max_speed):
		_sprint_glide = false


## While the in-world menu is open the movement input drives the menu and the player stands still (the world keeps running).
func _on_menu_opened(_labels: PackedStringArray, _selected: int) -> void:
	_menu_open = true


func _on_menu_closed() -> void:
	_menu_open = false


## Pointer scheme: never travel further than the cursor within one physics step, so arrival
## does not depend on the frame rate or on how much speed is left when the stop radius is reached.
func _limit_to_cursor(delta: float) -> void:
	if _pointer_offset == null:
		return
	var offset := _pointer_offset as Vector3
	var step: float = velocity.length() * delta
	var remaining: float = offset.length()
	if step <= remaining or step <= 0.0 or velocity.dot(offset) <= 0.0:
		return
	velocity = velocity * (remaining / step)


## Puts the player on the map spawn and (re)applies the persistent identity.
func spawn() -> void:
	_moving = false
	_moved_this_run = false
	if map_loader != null:
		global_position = map_loader.spawn_position
	velocity = Vector3.ZERO
	_touching = false
	_hit_cooldown = 0.0
	_sprinting = false
	_sprint_glide = false
	_sprint_available = save_service != null and save_service.progress.death_count >= config.sprint_unlock_deaths
	if map_loader != null:
		_cell = map_loader.world_to_cell(global_position)
	if save_service != null:
		identity_glyph = save_service.ensure_identity(config.identity_pool)
	else:
		identity_glyph = config.identity_pool.fallback_glyph
	identity_changed.emit(identity_glyph)
	SignalBus.player_spawned.emit(global_position)


## Direction (length 0..1) the current input asks for. Zero before an input scheme is discovered or outside a run.
func _wanted_direction() -> Vector3:
	if run_manager == null or run_manager.phase != RunManager.Phase.PLAYING:
		return Vector3.ZERO
	_pointer_offset = null
	if _menu_open:
		return Vector3.ZERO
	match run_manager.state.input_scheme:
		InputScheme.KEYBOARD, InputScheme.GAMEPAD:
			var pad: Vector2 = Input.get_vector(config.action_left, config.action_right, config.action_up, config.action_down)
			return _screen_to_world(pad)
		InputScheme.MOUSE:
			var pull: Vector2 = _pointer_direction()
			return Vector3(pull.x, 0.0, pull.y)
	return Vector3.ZERO


## Rotates a screen-space input vector (x right, y down) onto the ground by the camera's current yaw
## (the view profile's yaw plus the player's own rotation, task-051).
func _screen_to_world(screen: Vector2) -> Vector3:
	var yaw: float = 0.0
	if camera_rig != null and camera_rig.view_config != null:
		yaw = deg_to_rad(camera_rig.current_yaw_degrees())
	return Vector3(screen.x, 0.0, screen.y).rotated(Vector3.UP, yaw)


## Direction (length 0..1) toward the cursor while the pointer action is held.
func _pointer_direction() -> Vector2:
	if not Input.is_action_pressed(config.action_pointer):
		return Vector2.ZERO
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return Vector2.ZERO
	var cursor: Vector2 = get_viewport().get_mouse_position()
	var target: Variant = _ground.intersects_ray(camera.project_ray_origin(cursor), camera.project_ray_normal(cursor))
	if target == null:
		return Vector2.ZERO
	var offset := Vector2((target as Vector3).x - global_position.x, (target as Vector3).z - global_position.z)
	_pointer_offset = Vector3(offset.x, 0.0, offset.y)
	var distance: float = offset.length()
	if distance <= config.pointer_stop_distance:
		return Vector2.ZERO
	return offset / distance * clampf(distance / config.pointer_full_speed_distance, 0.0, 1.0)


## Tells the bus when movement starts or stops during a run, and when the run's first move happens.
func _announce_motion() -> void:
	var playing: bool = run_manager != null and run_manager.phase == RunManager.Phase.PLAYING
	var moving: bool = playing and velocity.length() > config.moving_speed_threshold
	if moving == _moving:
		return
	_moving = moving
	if not playing:
		return
	SignalBus.player_motion_changed.emit(moving)
	if moving and not _moved_this_run:
		_moved_this_run = true
		SignalBus.narration_event.emit(NarrationEvents.FIRST_MOVE)
		if _sprint_available:
			SignalBus.narration_event.emit(NarrationEvents.SPRINT_UNLOCKED)


func _playing() -> bool:
	return run_manager != null and run_manager.phase == RunManager.Phase.PLAYING


## Announces every change of map cell during a run (the track record counts steps).
func _announce_step() -> void:
	if map_loader == null or not _playing():
		return
	var cell: Vector2i = map_loader.world_to_cell(global_position)
	if cell == _cell:
		return
	_cell = cell
	SignalBus.player_stepped.emit(cell)


## Narration: the body started pushing into something. A wall gives HIT_WALL, anything else (map edge, object) HIT_UNKNOWN.
func _announce_contact(delta: float) -> void:
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	if map_loader == null or not _playing() or move_intent.length_squared() <= 0.0:
		_touching = false
		return
	var push: Vector3 = move_intent.normalized()
	var touching: bool = false
	var probe: Vector3 = Vector3.ZERO
	for i in get_slide_collision_count():
		var contact: KinematicCollision3D = get_slide_collision(i)
		var normal: Vector3 = contact.get_normal()
		if -normal.dot(push) >= config.hit_min_facing:
			touching = true
			probe = contact.get_position() - normal * config.hit_probe_depth
			break
	if touching and not _touching and _hit_cooldown <= 0.0:
		_hit_cooldown = config.hit_cooldown_seconds
		var type: StringName = map_loader.data.type_at(map_loader.world_to_cell(probe))
		SignalBus.narration_event.emit(NarrationEvents.HIT_WALL if type == MapLegend.WALL else NarrationEvents.HIT_UNKNOWN)
	_touching = touching


## Picks the movement of the active form: its DB movement_profile row, else the default row, else PlayerConfig.
## Called on every form change and every DB (re)load, so tuning in the god window applies during play.
func apply_movement_profile() -> void:
	var row: Dictionary = movement_row(String(form))
	if row.is_empty():
		row = movement_row(config.default_movement_profile)
	max_speed = float(row.get("max_speed", config.max_speed))
	acceleration = float(row.get("acceleration", config.acceleration))
	deceleration = float(row.get("deceleration", config.friction))
	sprint_speed_mult = float(row.get("sprint_speed_mult", config.sprint_speed_mult))
	sprint_accel_mult = float(row.get("sprint_accel_mult", config.sprint_accel_mult))
	sprint_decel_mult = float(row.get("sprint_decel_mult", config.sprint_decel_mult))


## The DB movement_profile row of a profile id, or empty.
func movement_row(profile: String) -> Dictionary:
	if database == null or profile == "":
		return {}
	for row: Variant in database.rows("movement_profile"):
		if row is Dictionary and str((row as Dictionary).get("profile", "")) == profile:
			return row
	return {}


func _on_entity_form_changed(new_form: StringName, _animate: bool) -> void:
	form = new_form
	apply_movement_profile()
