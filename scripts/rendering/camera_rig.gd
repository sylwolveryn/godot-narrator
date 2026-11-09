class_name CameraRig
extends Node3D
## Camera rig. The base view comes from its CameraViewConfig (isometric orthographic in the game);
## the player can orbit it around the follow target (Q / E held, right mouse drag) and zoom it
## (mouse wheel, PgUp / PgDn) within the profile's limits (task-051). Follows an optional target
## on the XZ plane, looking at a point `look_height` above the floor.
## Player movement reads current_yaw_degrees() so "up" stays up on screen after rotating.

@export var view_config: CameraViewConfig
@export var follow_target: Node3D

@onready var camera: Camera3D = $Camera3D

## Current and requested yaw in degrees (unwrapped; both shift together when they grow large).
var _yaw: float = 0.0
var _yaw_goal: float = 0.0
## Current and requested zoom, as a multiple of the profile's size (ortho) or distance (perspective).
var _zoom: float = 1.0
var _zoom_goal: float = 1.0
## View override (task-068, teleport travel): while set, a presentation node places the rig and sets the zoom every
## frame (override_view); the follow and the player's zoom input pause. release_override() hands back to the follow
## (smoothed) and to the zoom the player had asked for.
var _override: bool = false
var _zoom_goal_saved: float = 1.0
## Task-090: the active entity form's zoom factor (CameraViewConfig.form_zoom); scales zoom_max.
var _form_zoom: float = 1.0
## One full turn in degrees; used to keep the unwrapped yaw small.
const FULL_TURN: float = 360.0


func _ready() -> void:
	if view_config == null:
		view_config = CameraViewConfig.new()
	apply_view(view_config)
	SignalBus.player_spawned.connect(_on_player_spawned)
	SignalBus.entity_form_changed.connect(_on_entity_form_changed)


func _process(delta: float) -> void:
	_update_rotation_keys(delta)
	_update_view(delta)
	if follow_target == null or _override:
		return
	var goal: Vector3 = _goal()
	if view_config.follow_smoothing <= 0.0:
		global_position = goal
	else:
		global_position = global_position.lerp(goal, clampf(delta / view_config.follow_smoothing, 0.0, 1.0))


## Wheel / page keys zoom, right-drag rotates. Unhandled only, so the menu and the intro go first.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if view_config.rotation_enabled and Input.is_action_pressed(view_config.action_drag):
			rotate_by(-(event as InputEventMouseMotion).relative.x * view_config.drag_degrees_per_pixel)
		return
	if not view_config.zoom_enabled or _override:
		return
	if event.is_action_pressed(view_config.action_zoom_in, true):
		zoom_by(-1.0)
	elif event.is_action_pressed(view_config.action_zoom_out, true):
		zoom_by(1.0)


## Applies a view profile and resets the player's rotation and zoom to it.
func apply_view(config: CameraViewConfig) -> void:
	view_config = config
	_yaw = config.yaw_degrees
	_yaw_goal = _yaw
	_zoom = 1.0
	_zoom_goal = 1.0
	camera.near = config.near
	camera.far = config.far
	position.y = config.look_height
	if config.orthographic:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = config.fov
	_apply_transform()


## Requests a yaw change in degrees (positive swings the camera to its right).
func rotate_by(degrees: float) -> void:
	_yaw_goal += degrees
	if absf(_yaw_goal) > FULL_TURN:
		var turns: float = FULL_TURN * signf(_yaw_goal)
		_yaw_goal -= turns
		_yaw -= turns


## Requests `steps` zoom steps (negative zooms in), clamped to the profile's limits.
func zoom_by(steps: float) -> void:
	_zoom_goal = clampf(_zoom_goal * pow(1.0 + view_config.zoom_step, steps), view_config.zoom_min, zoom_limit())


## Furthest zoom right now: the profile's zoom_max times the active form's factor (task-090).
func zoom_limit() -> float:
	return view_config.zoom_max * _form_zoom


## A new entity form: its zoom factor scales the limit, and the requested zoom moves by the change, so a bigger body
## sees proportionally more (and switching back returns to the zoom the player had).
func _on_entity_form_changed(form: StringName, _animate: bool) -> void:
	var factor: float = maxf(float(view_config.form_zoom.get(form, 1.0)), 0.01)
	if is_equal_approx(factor, _form_zoom):
		return
	var change: float = factor / _form_zoom
	_form_zoom = factor
	_zoom_goal = clampf(_zoom_goal * change, view_config.zoom_min, zoom_limit())
	if _override:
		_zoom_goal_saved = clampf(_zoom_goal_saved * change, view_config.zoom_min, zoom_limit())


## The yaw the view shows right now, in degrees (what screen-relative movement must use).
func current_yaw_degrees() -> float:
	return _yaw


## The zoom the view shows right now (1 = the profile's own size / distance).
func current_zoom() -> float:
	return _zoom


## Places the rig over a floor point and shows `zoom` (multiple of the profile's size) right now, pausing the follow
## and the zoom input until release_override(). Called every frame by whoever drives the view (e.g. TeleportView).
## The zoom may go up to the profile's zoom_max; values outside zoom_min..zoom_max are clamped.
func override_view(world_position: Vector3, zoom: float) -> void:
	if not _override:
		_override = true
		_zoom_goal_saved = _zoom_goal
	global_position = Vector3(world_position.x, view_config.look_height, world_position.z)
	_zoom = clampf(zoom, view_config.zoom_min, zoom_limit())
	_zoom_goal = _zoom
	_apply_transform()


## Ends a view override: the follow takes over again (smoothed from where the override left the rig) and the zoom eases
## back to the one the player had asked for.
func release_override() -> void:
	if not _override:
		return
	_override = false
	_zoom_goal = _zoom_goal_saved


## True while a view override is in effect.
func is_overridden() -> bool:
	return _override


## The zoom the player asked for (the goal), ignoring an override in effect.
func requested_zoom() -> float:
	return _zoom_goal_saved if _override else _zoom_goal


## Jumps straight to the follow target (no smoothing), e.g. after a respawn.
func snap_to_target() -> void:
	if follow_target != null:
		global_position = _goal()


func _update_rotation_keys(delta: float) -> void:
	if not view_config.rotation_enabled:
		return
	var axis: float = Input.get_axis(view_config.action_rotate_left, view_config.action_rotate_right)
	if axis != 0.0:
		rotate_by(axis * view_config.rotate_speed_degrees * delta)


## Eases the shown yaw and zoom toward the requested ones; touches the transform only while they differ.
func _update_view(delta: float) -> void:
	if _yaw == _yaw_goal and _zoom == _zoom_goal:
		return
	_yaw = _ease(_yaw, _yaw_goal, view_config.rotation_smoothing, view_config.rotation_settle_degrees, delta)
	_zoom = _ease(_zoom, _zoom_goal, view_config.zoom_smoothing, view_config.zoom_settle, delta)
	_apply_transform()


## Frame-rate independent approach of `goal`; snaps when within `settle` or when smoothing is off.
func _ease(value: float, goal: float, smoothing: float, settle: float, delta: float) -> float:
	if smoothing <= 0.0:
		return goal
	var next: float = lerpf(value, goal, 1.0 - exp(-delta / smoothing))
	return goal if absf(goal - next) <= settle else next


func _apply_transform() -> void:
	rotation = Vector3(deg_to_rad(view_config.pitch_degrees), deg_to_rad(_yaw), 0.0)
	if view_config.orthographic:
		camera.position = Vector3(0.0, 0.0, view_config.distance)
		camera.size = view_config.size * _zoom
	else:
		camera.position = Vector3(0.0, 0.0, view_config.distance * _zoom)


func _goal() -> Vector3:
	return Vector3(follow_target.global_position.x, view_config.look_height, follow_target.global_position.z)


func _on_player_spawned(_world_position: Vector3) -> void:
	snap_to_target()
