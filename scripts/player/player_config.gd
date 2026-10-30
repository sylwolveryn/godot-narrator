class_name PlayerConfig
extends Resource
## Tunables for the player body, its movement, its input actions and how its identity glyph is drawn.

@export var identity_pool: IdentityPool
## Collision capsule.
@export var body_radius: float = 0.35
@export var body_height: float = 0.9

@export_group("Movement")
## Top speed in world units per second.
@export var max_speed: float = 4.5
## Speed (units per second) above which the player counts as moving (narration: first move, idle).
@export var moving_speed_threshold: float = 0.3
## Units per second squared while input is held.
@export var acceleration: float = 30.0
## Units per second squared when input stops.
@export var friction: float = 40.0
## Mouse scheme: within this distance (world units) of the cursor the player stops.
@export var pointer_stop_distance: float = 0.15
## Mouse scheme: distance at which the pointer pull reaches full strength (smaller = slower near the cursor).
@export var pointer_full_speed_distance: float = 1.0

@export_group("Input actions")
## InputMap action names (defined in project.godot).
@export var action_left: StringName = &"move_left"
@export var action_right: StringName = &"move_right"
@export var action_up: StringName = &"move_up"
@export var action_down: StringName = &"move_down"
## Mouse scheme: while held, move toward the cursor.
@export var action_pointer: StringName = &"move_pointer"

@export_group("Overlay glyph")
@export var font_names: PackedStringArray = PackedStringArray(["Segoe UI Symbol", "Nirmala UI", "Segoe UI", "Consolas", "monospace"])
@export var font_size: int = 88
@export var glyph_color: Color = Color("#FFF6E6")
@export var outline_color: Color = Color(1.0, 0.7, 0.28, 0.4)
@export var outline_size: int = 12
