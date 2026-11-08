class_name PlayerConfig
extends Resource
## Tunables for the player body, its movement, its input actions and how its identity glyph is drawn (PlayerGlyphView).

@export var identity_pool: IdentityPool
## Collision capsule.
@export var body_radius: float = 0.35
@export var body_height: float = 0.9

@export_group("Movement")
## Fallback movement, used until the DB table `movement_profile` is read and for a form without a row there. The DB rows
## (task-055: "default", "single", "grown") replace these at run time; the active entity form picks its row.
## Top speed in world units per second.
@export var max_speed: float = 4.5
## Speed (units per second) above which the player counts as moving (narration: first move, idle).
@export var moving_speed_threshold: float = 0.3
## Units per second squared while input is held (a hint of inertia: about 0.3 s to full speed).
@export var acceleration: float = 14.0
## Units per second squared when input stops.
@export var friction: float = 16.0
## DB movement_profile row used when the active form has no row of its own.
@export var default_movement_profile: String = "default"
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

@export_group("In-world glyph")
## Fonts the identity glyph is rasterised with (first available, then the system fallbacks).
@export var font_names: PackedStringArray = PackedStringArray(["Segoe UI Symbol", "Nirmala UI", "Segoe UI", "Consolas", "monospace"])
@export var glyph_color: Color = Color("#FFF6E6")
## Height above the player's feet where the in-world glyph is centred (world units).
@export var glyph_height: float = 0.55

@export_group("Contacts")
## Seconds before another HIT_WALL / HIT_UNKNOWN can be announced after one.
@export var hit_cooldown_seconds: float = 2.5
## How directly the input must push into the obstacle (dot of the push direction and the contact normal, 0..1).
@export_range(0.0, 1.0) var hit_min_facing: float = 0.6
## Distance behind the contact point (world units) used to find the cell that was hit.
@export var hit_probe_depth: float = 0.1
