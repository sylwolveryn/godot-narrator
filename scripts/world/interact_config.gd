class_name InteractConfig
extends Resource
## Interact control (task-072): the action, the default reach and the look of the hint glyph near the player.
## Instance: resources/config/interact_config.tres (tools/build_resources.gd).

## InputMap action (Space, left mouse button, gamepad X; tools/build_input_map.gd).
@export var action: StringName = &"interact"
## Default reach of an interactable in cells around its footprint (1 = the 8 neighbour cells).
@export_range(1, 8) var default_reach: int = 1
## Task-094: the grown (many) body reaches an object when its outline comes this close (world units) to the footprint
## (each cell of reach beyond the first adds a cell).
@export var body_reach: float = 0.6

@export_group("Hint")
## Glyph shown above the player while an interactable is in reach.
@export var hint_text: String = "◆"
@export var hint_color: Color = Color(1.0, 0.82, 0.35)
@export var hint_outline_color: Color = Color(0.05, 0.03, 0.0, 0.9)
@export_range(0, 32) var hint_outline_size: int = 8
@export_range(8, 128) var hint_font_size: int = 48
## World height of the hint glyph and how high above the player's feet it floats.
@export var hint_height: float = 0.32
@export var hint_lift: float = 1.25
## The hint leans this share of the way from the player towards the interactable.
@export_range(0.0, 1.0) var hint_lean: float = 0.25
## Pulse of the hint's opacity: cycles per second and the lowest opacity.
@export var hint_pulse_hz: float = 1.6
@export_range(0.0, 1.0) var hint_pulse_min: float = 0.45
@export var hint_font_names: PackedStringArray = PackedStringArray(["Consolas", "Segoe UI Symbol", "DejaVu Sans", "monospace"])
