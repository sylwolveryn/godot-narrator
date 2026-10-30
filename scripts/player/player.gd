class_name Player
extends CharacterBody3D
## The player body. Placed at the map's spawn cell on every run_started. It has no mesh:
## its visible identity is a glyph drawn on the overlay layer (decision-001).
## Movement arrives with task-009.

## Emitted when the identity glyph is (re)assigned. The overlay listens.
signal identity_changed(glyph: String)

@export var config: PlayerConfig
@export var map_loader: MapLoader
@export var save_service: SaveService

var identity_glyph: String = ""


func _ready() -> void:
	if config == null:
		config = PlayerConfig.new()
	if config.identity_pool == null:
		config.identity_pool = IdentityPool.new()
	SignalBus.run_started.connect(_on_run_started)


func _on_run_started(_run_index: int) -> void:
	spawn()


## Puts the player on the map spawn and (re)applies the persistent identity.
func spawn() -> void:
	if map_loader != null:
		global_position = map_loader.spawn_position
	velocity = Vector3.ZERO
	if save_service != null:
		identity_glyph = save_service.ensure_identity(config.identity_pool)
	else:
		identity_glyph = config.identity_pool.fallback_glyph
	identity_changed.emit(identity_glyph)
	SignalBus.player_spawned.emit(global_position)
