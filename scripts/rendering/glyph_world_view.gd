class_name GlyphWorldView
extends Node
## Feeds the glyph-surface material (shaders/glyph_surface.gdshader) of the built map: the static look
## from GlyphWorldConfig, the player light, the nearest static lights (items, spike and corruption
## patches whose cells have been seen) and the wall cut-away around the player. Read-only towards the
## game: it never writes data, it only sets shader uniforms.

const MAX_LIGHTS: int = 8
const PLAYER_LIGHT_SLOT: int = 0

@export var config: GlyphWorldConfig
@export var map_loader: MapLoader
@export var player: Node3D
## Optional. Static lights of cells that were never seen are left out, so hidden items do not glow through walls.
@export var map_reveal: MapReveal

## The material being fed (the loader's surface material).
var material: ShaderMaterial

var _sources: Array[GlyphLightSource] = []
var _light_pos: PackedVector4Array = PackedVector4Array()
var _light_col: PackedVector4Array = PackedVector4Array()
var _light_count: int = 1
var _last_cell: Vector2i = Vector2i(-1000000, -1000000)
var _dirty: bool = true


func _ready() -> void:
	if config == null:
		config = GlyphWorldConfig.new()
	_light_pos.resize(MAX_LIGHTS)
	_light_col.resize(MAX_LIGHTS)
	SignalBus.player_spawned.connect(_on_player_spawned)
	if map_loader != null:
		map_loader.map_built.connect(_on_map_built)
		if not map_loader.data.is_empty():
			_on_map_built(map_loader.data)


func _process(_delta: float) -> void:
	if material == null or player == null:
		return
	var pos: Vector3 = player.global_position
	var cell: Vector2i = map_loader.world_to_cell(pos)
	if _dirty or cell != _last_cell:
		_last_cell = cell
		_dirty = false
		_select_static_lights(pos)
	_light_pos[PLAYER_LIGHT_SLOT] = Vector4(pos.x, config.player_light_height, pos.z, config.player_light_radius)
	material.set_shader_parameter(&"light_pos", _light_pos)
	material.set_shader_parameter(&"cut_center", Vector4(pos.x, pos.y + config.cutaway_height, pos.z, config.cutaway_radius))


## Pushes the static look of the config into the material.
func apply_static() -> void:
	if material == null:
		return
	var dark := PackedVector4Array()
	var bright := PackedVector4Array()
	for i in GlyphSurfaceType.COUNT:
		dark.append(_vec(config.palette_dark[i]))
		bright.append(_vec(config.palette_bright[i]))
	material.set_shader_parameter(&"pal_dark", dark)
	material.set_shader_parameter(&"pal_bright", bright)
	material.set_shader_parameter(&"emit", config.emissive)
	material.set_shader_parameter(&"corrupt_hue_a", _rgb(config.corrupt_hue_a))
	material.set_shader_parameter(&"corrupt_hue_b", _rgb(config.corrupt_hue_b))
	material.set_shader_parameter(&"glint_color", _rgb(config.glint_color))
	material.set_shader_parameter(&"cell_screen", config.cell_screen)
	material.set_shader_parameter(&"cell_aspect", config.cell_aspect)
	material.set_shader_parameter(&"glyph_crop", config.glyph_crop)
	material.set_shader_parameter(&"ambient_level", config.ambient_level)
	material.set_shader_parameter(&"tint_mix", config.tint_mix)
	material.set_shader_parameter(&"memory_dim", config.memory_dim)
	material.set_shader_parameter(&"memory_saturation", config.memory_saturation)
	material.set_shader_parameter(&"cut_params", Vector2(config.cutaway_soft, config.cutaway_margin))
	if map_loader != null and map_loader.world_config != null:
		material.set_shader_parameter(&"wall_height", map_loader.world_config.wall_height)
	var player_col := Vector3(config.player_light_color.r, config.player_light_color.g, config.player_light_color.b)
	_light_col[PLAYER_LIGHT_SLOT] = Vector4(player_col.x, player_col.y, player_col.z, 1.0) * config.player_light_intensity
	_dirty = true


## Number of lights the shader currently loops over (player light included).
func light_count() -> int:
	return _light_count


func _on_map_built(map: MapData) -> void:
	material = map_loader.surface_material as ShaderMaterial
	if material == null:
		return
	_sources = GlyphLightSource.collect(map, map_loader.world_config, config)
	apply_static()


func _on_player_spawned(_world_position: Vector3) -> void:
	_dirty = true


## The nearest static lights whose cells are known to the player, after the player light.
func _select_static_lights(pos: Vector3) -> void:
	var candidates: Array[GlyphLightSource] = []
	for src in _sources:
		if _is_known(src):
			candidates.append(src)
	candidates.sort_custom(func(a: GlyphLightSource, b: GlyphLightSource) -> bool:
		return a.position.distance_squared_to(pos) < b.position.distance_squared_to(pos))
	var count: int = mini(candidates.size(), config.max_static_lights)
	for i in count:
		var src: GlyphLightSource = candidates[i]
		_light_pos[PLAYER_LIGHT_SLOT + 1 + i] = Vector4(src.position.x, src.position.y, src.position.z, src.radius)
		_light_col[PLAYER_LIGHT_SLOT + 1 + i] = Vector4(src.color.x, src.color.y, src.color.z, 1.0)
	_light_count = PLAYER_LIGHT_SLOT + 1 + count
	material.set_shader_parameter(&"light_col", _light_col)
	material.set_shader_parameter(&"light_count", _light_count)


func _is_known(src: GlyphLightSource) -> bool:
	if map_reveal == null:
		return true
	for c in src.cells:
		if map_reveal.state_of(c) != MapReveal.CellState.HIDDEN:
			return true
	return false


static func _vec(c: Color) -> Vector4:
	return Vector4(c.r, c.g, c.b, 1.0)


static func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
