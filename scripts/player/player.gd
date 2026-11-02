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
## Source of the active camera view; keyboard and gamepad input is rotated by its yaw so
## "up" means up on screen.
@export var camera_rig: CameraRig

var identity_glyph: String = ""
## Direction the input asks for this physics step on the ground (length 0..1, zero when idle). Differs from the
## velocity when the body is blocked; PushableObjects reads it to know what is being pushed.
var move_intent: Vector3 = Vector3.ZERO

var _ground: Plane = Plane(Vector3.UP, 0.0)
var _moving: bool = false
var _moved_this_run: bool = false
var _menu_open: bool = false
## Ground offset from the player to the cursor while the pointer is held, else null.
var _pointer_offset: Variant = null


func _ready() -> void:
	if config == null:
		config = PlayerConfig.new()
	if config.identity_pool == null:
		config.identity_pool = IdentityPool.new()
	# Top-down: no floor or gravity, the body slides on the XZ plane.
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	SignalBus.run_started.connect(_on_run_started)
	SignalBus.menu_opened.connect(_on_menu_opened)
	SignalBus.menu_closed.connect(_on_menu_closed)


func _physics_process(delta: float) -> void:
	var wanted: Vector3 = _wanted_velocity()
	move_intent = wanted / config.max_speed
	var rate: float = config.acceleration if wanted != Vector3.ZERO else config.friction
	velocity = velocity.move_toward(wanted, rate * delta)
	velocity.y = 0.0
	_limit_to_cursor(delta)
	move_and_slide()
	global_position.y = 0.0
	_announce_motion()


func _on_run_started(_run_index: int) -> void:
	spawn()


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
	if save_service != null:
		identity_glyph = save_service.ensure_identity(config.identity_pool)
	else:
		identity_glyph = config.identity_pool.fallback_glyph
	identity_changed.emit(identity_glyph)
	SignalBus.player_spawned.emit(global_position)


## Velocity the current input asks for. Zero before an input scheme is discovered or outside a run.
func _wanted_velocity() -> Vector3:
	if run_manager == null or run_manager.phase != RunManager.Phase.PLAYING:
		return Vector3.ZERO
	_pointer_offset = null
	if _menu_open:
		return Vector3.ZERO
	match run_manager.state.input_scheme:
		InputScheme.KEYBOARD, InputScheme.GAMEPAD:
			var pad: Vector2 = Input.get_vector(config.action_left, config.action_right, config.action_up, config.action_down)
			return _screen_to_world(pad) * config.max_speed
		InputScheme.MOUSE:
			var pull: Vector2 = _pointer_direction()
			return Vector3(pull.x, 0.0, pull.y) * config.max_speed
	return Vector3.ZERO


## Rotates a screen-space input vector (x right, y down) onto the ground by the camera view's yaw.
func _screen_to_world(screen: Vector2) -> Vector3:
	var yaw: float = 0.0
	if camera_rig != null and camera_rig.view_config != null:
		yaw = deg_to_rad(camera_rig.view_config.yaw_degrees)
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
