class_name CameraViewConfig
extends Resource
## A camera view profile. Swap profiles on CameraRig to change the view
## (e.g. isometric vs top-down) without touching the world scene.

@export var orthographic: bool = true
## Orthographic size (vertical extent in world units) or perspective FOV in degrees.
@export var size: float = 12.0
@export var fov: float = 60.0
## Pitch in degrees. -90 looks straight down.
@export_range(-90.0, 0.0, 0.1) var pitch_degrees: float = -90.0
## Yaw in degrees around the vertical axis. 45 with the isometric pitch puts the camera at +x,+z.
## The player orbits from here (CameraRig); WorldMeshBuilder emits every side face for that.
@export_range(-180.0, 180.0, 0.1) var yaw_degrees: float = 0.0
## Height above the floor of the point the camera looks at (the rig origin).
@export var look_height: float = 0.0
## Clip planes of the camera.
@export var near: float = 0.05
@export var far: float = 4000.0
## Distance of the camera from the rig origin along its look axis.
@export var distance: float = 20.0
## 0 snaps to the target; higher values follow more slowly (seconds to catch up).
@export var follow_smoothing: float = 0.15

@export_group("Player control")
## InputMap actions of the camera controls (task-051).
@export var action_rotate_left: StringName = &"camera_rotate_left"
@export var action_rotate_right: StringName = &"camera_rotate_right"
@export var action_zoom_in: StringName = &"camera_zoom_in"
@export var action_zoom_out: StringName = &"camera_zoom_out"
## Held to rotate with the mouse (right mouse button).
@export var action_drag: StringName = &"camera_drag"
## Whether the player may rotate this view (Q / E, drag).
@export var rotation_enabled: bool = true
## Yaw speed while a rotate key is held, degrees per second. rotate_left swings the camera to its
## left around the player (the scene appears to turn right), rotate_right the other way.
@export var rotate_speed_degrees: float = 110.0
## Yaw change per pixel of horizontal mouse movement while dragging. Positive makes the scene
## follow the cursor (drag right = camera swings left); negative inverts.
@export var drag_degrees_per_pixel: float = 0.35
## Seconds the yaw takes to catch up with the requested yaw (0 snaps).
@export_range(0.0, 1.0, 0.01) var rotation_smoothing: float = 0.08
## The eased yaw snaps to the requested yaw once closer than this (degrees), so the rig settles.
@export var rotation_settle_degrees: float = 0.01
## Whether the player may zoom this view (wheel, PgUp / PgDn).
@export var zoom_enabled: bool = true
## Zoom change per wheel notch or key press, as a fraction of the current zoom.
@export_range(0.01, 0.5, 0.01) var zoom_step: float = 0.1
## Zoom limits as multiples of the profile's `size` (orthographic) or `distance` (perspective).
## Below 1 is closer (zoomed in), above 1 is further out.
@export_range(0.1, 1.0, 0.01) var zoom_min: float = 0.55
@export_range(1.0, 4.0, 0.01) var zoom_max: float = 1.6
## Task-090: per entity form, a factor on zoom_max and on the requested zoom when that form is taken (a bigger body
## sees further; everything seems smaller). Forms not listed use 1.
@export var form_zoom: Dictionary[StringName, float] = {&"grown": 1.6}
## Seconds the zoom takes to catch up with the requested zoom (0 snaps).
@export_range(0.0, 1.0, 0.01) var zoom_smoothing: float = 0.1
## The eased zoom snaps to the requested zoom once closer than this (zoom multiple), so the rig settles.
@export var zoom_settle: float = 0.0005
