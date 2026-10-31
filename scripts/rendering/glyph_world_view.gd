class_name GlyphWorldView
extends Node
## Feeds the glyph-surface material (shaders/glyph_surface.gdshader) of the built map: the static look
## from GlyphWorldConfig, the player light, the nearest static lights (items, spike and corruption
## patches whose cells have been seen; they fade in and out), the light occlusion textures
## (GlyphVisibilityMap, filled from GlyphLightOcclusion) and the wall cut-away around the player.
## Read-only towards the game: it never writes data, it only sets shader uniforms.

const MAX_LIGHTS: int = 8
const PLAYER_LIGHT_SLOT: int = 0
## A player move of more than this many cells in one step (a teleport) replaces the occlusion of the
## player light at once instead of blending it.
const JUMP_CELLS: int = 2

@export var config: GlyphWorldConfig
@export var map_loader: MapLoader
@export var player: Node3D
## Optional. Static lights of cells that were never seen are left out, so hidden items do not glow through walls.
@export var map_reveal: MapReveal

## The material being fed (the loader's surface material).
var material: ShaderMaterial

var _map: MapData
var _sources: Array[GlyphLightSource] = []
## Static light slots (slot i feeds shader light i + 1); null = free.
var _slots: Array[GlyphLightSource] = []
var _fade: Dictionary[GlyphLightSource, float] = {}
var _desired: Dictionary[GlyphLightSource, bool] = {}
var _visibility: GlyphVisibilityMap
var _player_vis_cell: Vector2i = Vector2i(-1000000, -1000000)
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
	if map_reveal != null:
		map_reveal.cells_seen.connect(_on_cells_seen)
	if map_loader != null:
		map_loader.map_built.connect(_on_map_built)
		if not map_loader.data.is_empty():
			_on_map_built(map_loader.data)


func _process(delta: float) -> void:
	if material == null or player == null:
		return
	var pos: Vector3 = player.global_position
	var cell: Vector2i = map_loader.world_to_cell(pos)
	if _dirty or cell != _last_cell:
		_last_cell = cell
		_dirty = false
		_retarget(pos)
		_update_player_visibility(cell)
	_step_fades(delta)
	if _visibility != null:
		_visibility.step(delta)
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
	material.set_shader_parameter(&"memory_tint", _rgb(config.memory_tint))
	material.set_shader_parameter(&"memory_density", config.memory_density)
	material.set_shader_parameter(&"memory_dropout", config.memory_dropout)
	material.set_shader_parameter(&"memory_emit", config.memory_emit)
	material.set_shader_parameter(&"memory_floor", config.memory_floor)
	material.set_shader_parameter(&"reveal_spread", config.reveal_spread)
	material.set_shader_parameter(&"cut_params", Vector2(config.cutaway_soft, config.cutaway_margin))
	material.set_shader_parameter(&"cut_edge_dim", config.cutaway_edge_dim)
	material.set_shader_parameter(&"light_falloff_sharp", config.light_falloff_sharp)
	material.set_shader_parameter(&"wall_block", config.wall_block_size)
	material.set_shader_parameter(&"floor_tile", config.floor_tile_size)
	material.set_shader_parameter(&"seam_width", config.seam_width)
	material.set_shader_parameter(&"seam_dim", config.seam_dim)
	material.set_shader_parameter(&"block_variation", config.block_variation)
	material.set_shader_parameter(&"edge_width", config.edge_width)
	material.set_shader_parameter(&"edge_gain", config.edge_gain)
	material.set_shader_parameter(&"edge_ambient", config.edge_ambient)
	material.set_shader_parameter(&"wall_base_dark", config.wall_base_dark)
	material.set_shader_parameter(&"wall_ao_height", config.wall_ao_height)
	material.set_shader_parameter(&"wall_top_ambient", config.wall_top_ambient)
	material.set_shader_parameter(&"depth_near", config.depth_near)
	material.set_shader_parameter(&"depth_far", config.depth_far)
	material.set_shader_parameter(&"depth_ambient_min", config.depth_ambient_min)
	material.set_shader_parameter(&"fog_strength", config.fog_strength)
	material.set_shader_parameter(&"fog_start", config.fog_start)
	if map_loader != null and map_loader.world_config != null:
		material.set_shader_parameter(&"wall_height", map_loader.world_config.wall_height)
	var player_col := Vector3(config.player_light_color.r, config.player_light_color.g, config.player_light_color.b)
	_light_col[PLAYER_LIGHT_SLOT] = Vector4(player_col.x, player_col.y, player_col.z, 1.0) * config.player_light_intensity
	_apply_visibility_params()
	_dirty = true


## Number of lights the shader currently loops over (player light included).
func light_count() -> int:
	return _light_count


## The light visibility textures (null before a map is built).
func visibility() -> GlyphVisibilityMap:
	return _visibility


## Current fade (0..1) of a static light source; 0 when it holds no slot.
func fade_of(src: GlyphLightSource) -> float:
	return _fade.get(src, 0.0)


## All static light sources of the built map.
func sources() -> Array[GlyphLightSource]:
	return _sources


func _on_map_built(map: MapData) -> void:
	material = map_loader.surface_material as ShaderMaterial
	if material == null:
		return
	_map = map
	var world: WorldConfig = map_loader.world_config
	_sources = GlyphLightSource.collect(map, world, config)
	for src in _sources:
		src.bake_visibility(map, world, config.occlusion_penumbra)
	_slots.clear()
	_slots.resize(MAX_LIGHTS - 1)
	_fade.clear()
	_desired.clear()
	_light_count = 1
	_visibility = GlyphVisibilityMap.new()
	_visibility.setup(map, config.occlusion_blend_time)
	_player_vis_cell = Vector2i(-1000000, -1000000)
	apply_static()


func _on_player_spawned(_world_position: Vector3) -> void:
	_dirty = true


## Cells were seen: the set of known static lights may have changed.
func _on_cells_seen() -> void:
	_dirty = true


## Picks the nearest known static lights and gives each a slot (a new light fades in from 0).
func _retarget(pos: Vector3) -> void:
	var candidates: Array[GlyphLightSource] = []
	for src in _sources:
		if _is_known(src):
			candidates.append(src)
	candidates.sort_custom(func(a: GlyphLightSource, b: GlyphLightSource) -> bool:
		return a.position.distance_squared_to(pos) < b.position.distance_squared_to(pos))
	_desired.clear()
	var count: int = mini(candidates.size(), mini(config.max_static_lights, _slots.size()))
	for i in count:
		_desired[candidates[i]] = true
	for i in _slots.size():
		var held: GlyphLightSource = _slots[i]
		if held != null and not _desired.has(held) and _fade.get(held, 0.0) <= 0.0:
			_free_slot(i)
	for src: GlyphLightSource in _desired:
		if _slots.has(src):
			continue
		var slot: int = _free_slot_index()
		if slot < 0:
			break
		_slots[slot] = src
		_fade[src] = 0.0
		_light_pos[PLAYER_LIGHT_SLOT + 1 + slot] = Vector4(src.position.x, src.position.y, src.position.z, src.radius)
		_light_col[PLAYER_LIGHT_SLOT + 1 + slot] = Vector4(0.0, 0.0, 0.0, 1.0)
		if config.occlusion_enabled:
			_visibility.assign(PLAYER_LIGHT_SLOT + 1 + slot, src.visibility)


## A free slot, or the slot of the faintest light that is on its way out; -1 when all hold wanted lights.
func _free_slot_index() -> int:
	var worst: int = -1
	var worst_fade: float = INF
	for i in _slots.size():
		var held: GlyphLightSource = _slots[i]
		if held == null:
			return i
		if not _desired.has(held) and _fade.get(held, 0.0) < worst_fade:
			worst_fade = _fade.get(held, 0.0)
			worst = i
	if worst >= 0:
		_free_slot(worst)
	return worst


func _free_slot(slot: int) -> void:
	var held: GlyphLightSource = _slots[slot]
	if held != null:
		_fade[held] = 0.0
	_slots[slot] = null
	_light_col[PLAYER_LIGHT_SLOT + 1 + slot] = Vector4(0.0, 0.0, 0.0, 1.0)
	if _visibility != null:
		_visibility.assign(PLAYER_LIGHT_SLOT + 1 + slot, {})


## Moves every slotted light's fade towards its target and pushes the colours and the light count.
func _step_fades(delta: float) -> void:
	var used: int = 0
	for i in _slots.size():
		var held: GlyphLightSource = _slots[i]
		if held == null:
			continue
		var wanted: bool = _desired.has(held)
		var f: float = _fade[held]
		var time: float = config.static_light_fade_in if wanted else config.static_light_fade_out
		f = move_toward(f, 1.0 if wanted else 0.0, delta / maxf(time, 0.001))
		_fade[held] = f
		_light_col[PLAYER_LIGHT_SLOT + 1 + i] = Vector4(held.color.x * f, held.color.y * f, held.color.z * f, 1.0)
		if not wanted and f <= 0.0:
			_free_slot(i)
			continue
		used = i + 1
	_light_count = PLAYER_LIGHT_SLOT + 1 + used
	material.set_shader_parameter(&"light_col", _light_col)
	material.set_shader_parameter(&"light_count", _light_count)


## Recomputes the occlusion of the player light when the player changed cell (blended, unless it jumped).
func _update_player_visibility(cell: Vector2i) -> void:
	if _visibility == null or not config.occlusion_enabled:
		return
	var world: WorldConfig = map_loader.world_config
	var values: Dictionary[Vector2i, float] = GlyphLightOcclusion.compute(
			_map, cell, config.player_light_radius / world.cell_size, config.occlusion_penumbra)
	var moved: int = maxi(absi(cell.x - _player_vis_cell.x), absi(cell.y - _player_vis_cell.y))
	_player_vis_cell = cell
	if moved > JUMP_CELLS:
		_visibility.assign(PLAYER_LIGHT_SLOT, values)
	else:
		_visibility.blend(PLAYER_LIGHT_SLOT, values)


func _apply_visibility_params() -> void:
	if _visibility == null or material == null:
		return
	var world: WorldConfig = map_loader.world_config
	material.set_shader_parameter(&"light_vis_a", _visibility.texture_a)
	material.set_shader_parameter(&"light_vis_b", _visibility.texture_b)
	material.set_shader_parameter(&"vis_params", Vector4(_visibility.size.x, _visibility.size.y, world.cell_size,
			1.0 if config.occlusion_enabled else 0.0))


## A static light shines only once one of its cells has been seen in this run; remembered cells stay dark.
func _is_known(src: GlyphLightSource) -> bool:
	if map_reveal == null:
		return true
	for c in src.cells:
		if map_reveal.state_of(c) == MapReveal.CellState.SEEN:
			return true
	return false


static func _vec(c: Color) -> Vector4:
	return Vector4(c.r, c.g, c.b, 1.0)


static func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
