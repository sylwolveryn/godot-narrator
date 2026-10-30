class_name SaveConfig
extends Resource
## Where persistent progress lives. Instance: resources/config/save_config.tres.
## Tests assign a temporary path so they never touch the player's real save.

## Location of the progress file.
@export var save_path: String = "user://progress.tres"
## Resource script paths a saved file may reference. Anything else is rejected before loading.
@export var allowed_script_paths: PackedStringArray = PackedStringArray(["res://scripts/core/persistent_progress.gd"])
## Longest identity glyph (in characters) accepted from a loaded file.
@export var max_identity_length: int = 8
