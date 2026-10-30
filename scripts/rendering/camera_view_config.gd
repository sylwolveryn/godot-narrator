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
## (The glyph-surface world builds only the faces seen from there, see WorldMeshBuilder.)
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
