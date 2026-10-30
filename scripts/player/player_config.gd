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
## Identity glyph size in reference pixels (scaled with the window height).
@export var font_size: int = 88
## Core and glow colour of the identity glyph (docs/visual_direction.md section 2) and the strength and
## SDF falloff of its halo.
@export var glyph_color: Color = Color("#FFF6E6")
@export var glow_color: Color = Color("#FFB347")
@export var glow_strength: float = 1.0
@export var glow_radius: float = 0.35
## Extra quad margin (share of the glyph size) so the halo fades out smoothly.
@export_range(0.0, 1.0) var glow_pad: float = 0.4
