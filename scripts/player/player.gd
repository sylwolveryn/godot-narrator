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

var identity_glyph: String = ""

var _ground: Plane = Plane(Vector3.UP, 0.0)


func _ready() -> void:
	if config == null:
		config = PlayerConfig.new()
	if config.identity_pool == null:
		config.identity_pool = IdentityPool.new()
	# Top-down: no floor or gravity, the body slides on the XZ plane.
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	SignalBus.run_started.connect(_on_run_started)


func _physics_process(delta: float) -> void:
	var wanted: Vector3 = _wanted_velocity()
	var rate: float = config.acceleration if wanted != Vector3.ZERO else config.friction
	velocity = velocity.move_toward(wanted, rate * delta)
	velocity.y = 0.0
	move_and_slide()
	global_position.y = 0.0


func _on_run_started(_run_index: int) -> void:
	spawn()


## Puts the player on the map spawn and (re)applies the persistent identity.
func spawn() -> void:
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
	var direction := Vector2.ZERO
	match run_manager.state.input_scheme:
		InputScheme.KEYBOARD, InputScheme.GAMEPAD:
			direction = Input.get_vector(config.action_left, config.action_right, config.action_up, config.action_down)
		InputScheme.MOUSE:
			direction = _pointer_direction()
	return Vector3(direction.x, 0.0, direction.y) * config.max_speed


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
	var distance: float = offset.length()
	if distance <= config.pointer_stop_distance:
		return Vector2.ZERO
	return offset / distance * clampf(distance / config.pointer_full_speed_distance, 0.0, 1.0)
