class_name CameraRig
extends Node3D
## Locked camera rig. Takes no player input; the view is driven only by its
## CameraViewConfig. Follows an optional target on the XZ plane.

@export var view_config: CameraViewConfig
@export var follow_target: Node3D

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	if view_config == null:
		view_config = CameraViewConfig.new()
	apply_view(view_config)


func _process(delta: float) -> void:
	if follow_target == null:
		return
	var goal := Vector3(follow_target.global_position.x, 0.0, follow_target.global_position.z)
	if view_config.follow_smoothing <= 0.0:
		global_position = goal
	else:
		global_position = global_position.lerp(goal, clampf(delta / view_config.follow_smoothing, 0.0, 1.0))


## Applies a view profile. This is the only way the view changes.
func apply_view(config: CameraViewConfig) -> void:
	view_config = config
	rotation = Vector3(deg_to_rad(config.pitch_degrees), 0.0, 0.0)
	camera.position = Vector3(0.0, 0.0, config.distance)
	if config.orthographic:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = config.size
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = config.fov
