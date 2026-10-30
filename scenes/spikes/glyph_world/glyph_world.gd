extends Node3D
## SPIKE A (task-027, throwaway). Autopilot player marker that carries the light through the M1 slice.
## All geometry, lights and the path are baked by tools/build_spike_glyph_world.gd.
## Run: godot --path . --max-fps 30 res://scenes/spikes/glyph_world/glyph_world.tscn

const MAX_LIGHTS: int = 8

## Waypoints (world space, y ignored) the marker loops through.
@export var path_points: PackedVector3Array = PackedVector3Array()
@export var speed: float = 2.2
## Static lights: xyz position, w radius (slot 0 is reserved for the player).
@export var static_light_pos: PackedVector4Array = PackedVector4Array()
@export var static_light_col: PackedVector4Array = PackedVector4Array()
@export var player_light_color: Color = Color(1.0, 0.82, 0.5)
@export var player_light_intensity: float = 1.4
@export var player_light_radius: float = 7.5
@export var player_light_height: float = 1.1
@export var marker_height: float = 0.55
@export var world_material: ShaderMaterial

@onready var _player: Node3D = $Player

var _light_pos: PackedVector4Array = PackedVector4Array()
var _light_col: PackedVector4Array = PackedVector4Array()
var _seg_len: PackedFloat32Array = PackedFloat32Array()
var _total_len: float = 0.0
var _dist: float = 0.0


func _ready() -> void:
	_light_pos.resize(MAX_LIGHTS)
	_light_col.resize(MAX_LIGHTS)
	for i in static_light_pos.size():
		_light_pos[i + 1] = static_light_pos[i]
		_light_col[i + 1] = static_light_col[i]
	_light_col[0] = Vector4(player_light_color.r, player_light_color.g, player_light_color.b, 1.0) * player_light_intensity
	_seg_len.resize(path_points.size())
	for i in path_points.size():
		var nxt: Vector3 = path_points[(i + 1) % path_points.size()]
		_seg_len[i] = Vector2(nxt.x - path_points[i].x, nxt.z - path_points[i].z).length()
		_total_len += _seg_len[i]
	world_material.set_shader_parameter("light_count", static_light_pos.size() + 1)
	_apply(_sample(0.0))


func _process(delta: float) -> void:
	_dist = fmod(_dist + speed * delta, _total_len)
	_apply(_sample(_dist))


## Position along the closed path at distance d.
func _sample(d: float) -> Vector3:
	var i: int = 0
	while d > _seg_len[i] and i < _seg_len.size() - 1:
		d -= _seg_len[i]
		i += 1
	var a: Vector3 = path_points[i]
	var b: Vector3 = path_points[(i + 1) % path_points.size()]
	return a.lerp(b, d / maxf(_seg_len[i], 0.0001))


func _apply(pos: Vector3) -> void:
	_player.position = Vector3(pos.x, marker_height, pos.z)
	_light_pos[0] = Vector4(pos.x, player_light_height, pos.z, player_light_radius)
	world_material.set_shader_parameter("light_pos", _light_pos)
	world_material.set_shader_parameter("light_col", _light_col)
