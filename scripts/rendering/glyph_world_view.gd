class_name GlyphWorldView
extends Node
## Feeds the glyph-surface material (shaders/glyph_surface.gdshader) of the built map: the static look
## from GlyphWorldConfig, the player light, the nearest static lights (items, spike and corruption
## patches whose cells have been seen; they fade in and out), the light occlusion textures
## (GlyphVisibilityMap, filled from GlyphLightOcclusion). There is no wall cut-away (task-052): the player rotates
## and zooms the camera to find a hidden avatar.
## Layered clarity (task-066): the selected language's understanding (SignalBus.language_understanding_changed) sets
## the share of glyph cells drawn layered (floor < hazards < items / objects, see glyph_surface.gdshader); the per-cell
## layer map (order, type, box height and half extent of items, hazards and pushable objects) is a tiny texture built
## here on map build and patched when an object is pushed.
## New menu item pulse (task-077): while SignalBus.menu_new_items_changed says items are new, a small rainbow ring
## pulses out of the player's centre every GlyphWorldConfig.pulse_interval seconds (shader uniforms pulse_geo /
## pulse_style, separate from the teleport waves).
## Read-only towards the game: it never writes data, it only sets shader uniforms.

const MAX_LIGHTS: int = 8
const PLAYER_LIGHT_SLOT: int = 0
## A player move of more than this many cells in one step (a teleport) replaces the occlusion of the
## player light at once instead of blending it.
const JUMP_CELLS: int = 2
## Layer map encoding (glyph_surface.gdshader LAYER_TYPES / LAYER_CODE): r = (order * LAYER_TYPES + type) / LAYER_CODE.
const LAYER_TYPES: int = 8
const LAYER_CODE: float = 255.0
## Neutral values of the fog / memory uniforms on maps without fog or darkness (task-069): factor 1, amount 0.
const FULL: float = 1.0
const NONE: float = 0.0

@export var config: GlyphWorldConfig
@export var map_loader: MapLoader
@export var player: Node3D
## Optional. Static lights of cells that were never seen are left out, so hidden items do not glow through walls.
@export var map_reveal: MapReveal
## Optional. Pushable objects take part in the layered clarity as items / objects do.
@export var pushables: PushableObjects
## Optional (task-069): the per-map visibility rules (fog, darkness, player light radius). Without it the config values apply.
@export var settings: MapSettingsResolver

## The material being fed (the loader's surface material).
var material: ShaderMaterial
## Visibility rules of the loaded map (task-069), resolved over `config` on every map build and DB reload.
var map_settings: MapSettings = MapSettings.new()

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
## Language understanding (0..1) of the selected language; 0 = the old interleaved look.
var _understanding: float = 0.0
var _layer_image: Image
var _layer_texture: ImageTexture
## New menu item pulse: on while items are new; seconds into the current interval; whether a ring is drawn.
var _pulse_on: bool = false
var _pulse_clock: float = 0.0
var _pulse_drawn: bool = false
## Ray height of the layer search (the tallest layered box), world units.
var _layer_height: float = 1.0


func _ready() -> void:
	if config == null:
		config = GlyphWorldConfig.new()
	_light_pos.resize(MAX_LIGHTS)
	_light_col.resize(MAX_LIGHTS)
	SignalBus.player_spawned.connect(_on_player_spawned)
	SignalBus.language_understanding_changed.connect(_on_understanding_changed)
	SignalBus.object_moved.connect(_on_object_moved)
	SignalBus.menu_new_items_changed.connect(_on_new_items_changed)
	if pushables != null:
		pushables.objects_reset.connect(_rebuild_layer_map)
	if map_reveal != null:
		map_reveal.cells_seen.connect(_on_cells_seen)
	if settings != null:
		settings.settings_changed.connect(apply_static)
	SignalBus.dirt_destroyed.connect(_on_dirt_destroyed)
	SignalBus.dirt_restored.connect(_on_dirt_restored)
	SignalBus.destructible_destroyed.connect(_on_destructible_changed)
	SignalBus.destructible_restored.connect(func(kind: StringName, rect: Rect2i) -> void:
		_on_destructible_changed(kind, rect, Vector3.ZERO, &""))
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
	_light_pos[PLAYER_LIGHT_SLOT] = Vector4(pos.x, config.player_light_height, pos.z, map_settings.player_light_radius)
	material.set_shader_parameter(&"light_pos", _light_pos)
	_step_pulse(delta, pos)


## True while the new menu item pulse runs.
func is_pulsing() -> bool:
	return _pulse_on


## The pulse ring right now: xz centre, radius, band (w 0 = no ring drawn).
func pulse_geo() -> Vector4:
	return material.get_shader_parameter(&"pulse_geo") if material != null else Vector4.ZERO


func _on_new_items_changed(pending: bool) -> void:
	if pending == _pulse_on:
		return
	_pulse_on = pending
	# The first ring starts at once.
	_pulse_clock = 0.0


## One ring per pulse_interval while items are new: it grows from the centre to pulse_radius_tiles over pulse_life and
## fades out (quadratic). Between rings, and while nothing is new, the uniform says "off" (band 0, no shader cost).
func _step_pulse(delta: float, pos: Vector3) -> void:
	var t: float = -1.0
	if _pulse_on:
		t = _pulse_clock / maxf(config.pulse_life, 0.01)
		_pulse_clock = fmod(_pulse_clock + delta, maxf(config.pulse_interval, config.pulse_life))
	if t < 0.0 or t >= 1.0:
		if _pulse_drawn:
			_pulse_drawn = false
			material.set_shader_parameter(&"pulse_geo", Vector4.ZERO)
		return
	var tile: float = map_loader.world_config.cell_size
	var grow: float = 1.0 - (1.0 - t) * (1.0 - t)
	var fade: float = (1.0 - t) * (1.0 - t)
	_pulse_drawn = true
	material.set_shader_parameter(&"pulse_geo", Vector4(pos.x, pos.z, grow * config.pulse_radius_tiles * tile,
			maxf(config.pulse_band_tiles * tile, 0.001)))
	material.set_shader_parameter(&"pulse_style", Vector3(config.pulse_strength * fade, config.pulse_hue_turns,
			config.pulse_hue_speed))


## Pushes the static look of the config into the material, with the visibility rules of the loaded map (task-069):
## no fog = no screen-top darkening and no ambient fade with distance; no darkness = full ambient light and remembered
## cells drawn like seen ones. A map without a map_settings row gets exactly the config values.
func apply_static() -> void:
	map_settings = MapSettings.resolve(settings.current_row() if settings != null else {}, null, config)
	if material == null:
		return
	var fog: bool = map_settings.fog_enabled
	var gloom: bool = map_settings.darkness_enabled
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
	material.set_shader_parameter(&"ambient_level", map_settings.ambient_level)
	material.set_shader_parameter(&"ambient_color", _rgb(map_settings.ambient_color))
	material.set_shader_parameter(&"tint_mix", config.tint_mix)
	material.set_shader_parameter(&"memory_dim", config.memory_dim if gloom else FULL)
	material.set_shader_parameter(&"memory_saturation", config.memory_saturation if gloom else FULL)
	material.set_shader_parameter(&"memory_tint", _rgb(config.memory_tint) if gloom else Vector3.ONE)
	material.set_shader_parameter(&"memory_density", config.memory_density if gloom else FULL)
	material.set_shader_parameter(&"memory_dropout", config.memory_dropout if gloom else NONE)
	material.set_shader_parameter(&"memory_emit", config.memory_emit if gloom else FULL)
	material.set_shader_parameter(&"memory_floor", config.memory_floor if gloom else NONE)
	material.set_shader_parameter(&"reveal_spread", config.reveal_spread)
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
	material.set_shader_parameter(&"depth_ambient_min", config.depth_ambient_min if fog else FULL)
	material.set_shader_parameter(&"fog_strength", config.fog_strength if fog else NONE)
	material.set_shader_parameter(&"fog_start", config.fog_start)
	if map_loader != null and map_loader.world_config != null:
		material.set_shader_parameter(&"wall_height", map_loader.world_config.wall_height)
		material.set_shader_parameter(&"object_params", Vector2(map_loader.world_config.object_height,
				map_loader.world_config.object_size_ratio * map_loader.world_config.cell_size * 0.5))
	var player_col := Vector3(config.player_light_color.r, config.player_light_color.g, config.player_light_color.b)
	_light_col[PLAYER_LIGHT_SLOT] = Vector4(player_col.x, player_col.y, player_col.z, 1.0) * config.player_light_intensity
	_apply_visibility_params()
	_apply_clarity()
	_dirty = true


## Share of glyph cells drawn layered (the shader's `clarity`), from the language understanding.
func clarity() -> float:
	return pow(clampf(_understanding, 0.0, 1.0), maxf(config.clarity_exponent, 0.001)) if _understanding > 0.0 else 0.0


## The per-cell layer map texture (null before a map is built).
func layer_texture() -> ImageTexture:
	return _layer_texture


## The CPU image behind the layer map texture (null before a map is built).
func layer_image() -> Image:
	return _layer_image


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
	_rebuild_layer_map()
	apply_static()


func _on_player_spawned(_world_position: Vector3) -> void:
	_dirty = true


## Cells were seen: the set of known static lights may have changed.
func _on_cells_seen() -> void:
	_dirty = true


func _on_understanding_changed(_language: StringName, understanding: float) -> void:
	_understanding = understanding
	_apply_clarity()


func _apply_clarity() -> void:
	if material == null:
		return
	material.set_shader_parameter(&"clarity", clarity())
	material.set_shader_parameter(&"layer_params", Vector2(_layer_height, float(config.layer_ray_samples)))
	if _layer_texture != null:
		material.set_shader_parameter(&"layer_map", _layer_texture)


## A dirt cell was destroyed (task-070): light now passes it. Re-bakes the static lights that reach it and lets the player
## light recompute its shadows (blended, as on a cell change).
func _on_dirt_destroyed(_map_id: StringName, cell: Vector2i, _cause: StringName) -> void:
	_refresh_occlusion(cell, false)


## Something else was destroyed or restored (task-073: a gargoyle's cells turned floor or back): the static lights that
## reach its cells are re-baked. Dirt is handled by dirt_destroyed / dirt_restored.
func _on_destructible_changed(kind: StringName, rect: Rect2i, _world: Vector3, _cause: StringName) -> void:
	if kind == DirtWalls.KIND:
		return
	_refresh_occlusion(rect.get_center(), false)


## Destroyed dirt cells are solid again (run start): the static lights that reach them are re-baked.
func _on_dirt_restored(cells: Array[Vector2i]) -> void:
	for cell in cells:
		_refresh_occlusion(cell, false)


func _refresh_occlusion(cell: Vector2i, everywhere: bool) -> void:
	if _map == null or map_loader == null or map_loader.world_config == null:
		return
	var world: WorldConfig = map_loader.world_config
	for src in _sources:
		if not everywhere and Vector2(src.origin_cell - cell).length() > src.radius / world.cell_size + 1.0:
			continue
		src.bake_visibility(_map, world, config.occlusion_penumbra)
		var slot: int = _slots.find(src)
		if slot >= 0 and config.occlusion_enabled and _visibility != null:
			_visibility.assign(PLAYER_LIGHT_SLOT + 1 + slot, src.visibility)
	_dirty = true


func _on_object_moved(_object_id: int, _from_cell: Vector2i, _to_cell: Vector2i, _form: StringName) -> void:
	_rebuild_layer_map()


## Per map cell: r = (order * LAYER_TYPES + surface type) / LAYER_CODE of its box (0 = none), g = box height /
## _layer_height, b = box half extent * 2 (cell fraction), a = 1 within layer_reach_cells of a box.
func _rebuild_layer_map() -> void:
	if _map == null or map_loader == null or map_loader.world_config == null:
		return
	var world: WorldConfig = map_loader.world_config
	var size := Vector2i(maxi(_map.width, 1), maxi(_map.height, 1))
	var boxes: Dictionary[Vector2i, Vector3] = {}   # cell -> (type, height, half extent)
	var spike_half: float = 0.5 - 0.5 / float(world.spike_pyramid_grid) + world.spike_pyramid_half
	var corrupt_half: float = 0.5 - 0.5 / float(world.corrupt_grid) + world.corrupt_column_half
	for y in _map.height:
		for x in _map.width:
			var c := Vector2i(x, y)
			match _map.type_at(c):
				MapLegend.ITEM:
					boxes[c] = Vector3(GlyphSurfaceType.ITEM, world.item_pillar_height, world.item_pillar_half)
				MapLegend.SPIKES:
					boxes[c] = Vector3(GlyphSurfaceType.SPIKES, world.spike_pyramid_height, spike_half)
				MapLegend.CORRUPT:
					var ch: float = WorldMeshBuilder.corruption_height(c, world)
					if ch > 0.0:
						boxes[c] = Vector3(GlyphSurfaceType.CORRUPT, ch, corrupt_half)
	if pushables != null:
		for id in pushables.count():
			boxes[pushables.cell_of(id)] = Vector3(GlyphSurfaceType.WALL, world.object_height, world.object_size_ratio * 0.5)
	_layer_height = maxf(maxf(world.item_pillar_height, world.spike_pyramid_height),
			maxf(world.corrupt_column_min + world.corrupt_column_span, world.object_height))
	if _layer_image == null or _layer_image.get_size() != size:
		_layer_image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	_layer_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var reach: int = config.layer_reach_cells
	for c: Vector2i in boxes:
		var box: Vector3 = boxes[c]
		var order: int = config.layer_order[int(box.x)] if int(box.x) < config.layer_order.size() else 0
		if order <= 0:
			continue
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var n := Vector2i(c.x + dx, c.y + dy)
				if n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y:
					continue
				var px: Color = _layer_image.get_pixelv(n)
				px.a = 1.0
				_layer_image.set_pixelv(n, px)
		if c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y:
			continue
		var code: float = float(order * LAYER_TYPES + int(box.x)) / LAYER_CODE
		_layer_image.set_pixelv(c, Color(code, clampf(box.y / _layer_height, 0.0, 1.0), clampf(box.z * 2.0, 0.0, 1.0), 1.0))
	if _layer_texture == null or Vector2i(_layer_texture.get_size()) != size:
		_layer_texture = ImageTexture.create_from_image(_layer_image)
	else:
		_layer_texture.update(_layer_image)
	_apply_clarity()


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
			_map, cell, map_settings.player_light_radius / world.cell_size, config.occlusion_penumbra)
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
