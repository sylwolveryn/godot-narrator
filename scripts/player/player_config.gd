class_name PlayerConfig
extends Resource
## Tunables for the player body and how its identity glyph is drawn on the overlay.

@export var identity_pool: IdentityPool
## Collision capsule.
@export var body_radius: float = 0.35
@export var body_height: float = 0.9
@export_group("Overlay glyph")
@export var font_names: PackedStringArray = PackedStringArray(["Segoe UI Symbol", "Nirmala UI", "Segoe UI", "Consolas", "monospace"])
@export var font_size: int = 44
@export var glyph_color: Color = Color(0.95, 0.97, 1.0)
@export var outline_color: Color = Color(0.0, 0.0, 0.0)
@export var outline_size: int = 6
