class_name DirtView
extends Node3D
## Draws the dirt walls (task-070). Presentation only: reads the map data and DirtWalls' chunking, listens to
## SignalBus.dirt_destroyed / dirt_restored, never writes data.
##  - Blocks: one MeshInstance3D per dirt chunk (WorldMeshBuilder.build_dirt_chunk, the shared glyph-surface material,
##    so reveal, light and occlusion work as on walls). Destroying a cell rebuilds its chunk, plus the neighbouring chunk
##    when the cell lies on a chunk edge (its face towards the cell appears). No per-frame work for standing dirt.
##  - Crumble: a pool of loose dirt blocks (one MultiMesh); an eaten cell's block sinks into the floor over
##    DirtConfig.crumble_duration (the only per-frame work: <= crumble_capacity transforms while something crumbles).
##  - Dust: glyph fragments thrown up and falling (one MultiMesh, shaders/dirt_dust.gdshader; motion in the shader).
## Also feeds the dirt palette uniforms of the glyph-surface material.

const DUST_SHADER: String = "res://shaders/dirt_dust.gdshader"
## Edge of the dust quad mesh; the instance scale is the half-size.
const QUAD_EXTENT: float = 2.0
## Transform of a hidden pool instance.
const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3(0.0, -1000.0, 0.0))
## Neighbours whose chunk may change when a cell changes.
const STEPS: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]

@export var config: DirtConfig
@export var map_loader: MapLoader
@export var dirt_walls: DirtWalls

var _builder := WorldMeshBuilder.new()
## Chunk -> its block mesh instance.
var _chunks: Dictionary[Vector2i, MeshInstance3D] = {}
var _crumble_mm: MultiMesh
## Active crumbles: [slot, world centre, elapsed].
var _crumbles: Array[Array] = []
var _next_crumble: int = 0
var _dust_mm: MultiMesh
var _dust_material: ShaderMaterial
var _dust_viewport: SubViewport
var _next_dust: int = 0
var _clock: float = 0.0
var _dust_until: float = -1.0
var _rng := RandomNumberGenerator.new()
## Chunks rebuilt since the map was built (tests / measurements).
var rebuilds: int = 0


func _ready() -> void:
	if config == null:
		config = DirtConfig.new()
	_rng.randomize()
	set_process(false)
	_build_pools()
	SignalBus.dirt_destroyed.connect(_on_dirt_destroyed)
	SignalBus.dirt_restored.connect(_on_dirt_restored)
	if map_loader != null:
		map_loader.map_built.connect(_on_map_built)
		if not map_loader.data.is_empty():
			_on_map_built(map_loader.data)


func _process(delta: float) -> void:
	_clock += delta
	_dust_material.set_shader_parameter(&"now", _clock)
	var duration: float = maxf(config.crumble_duration, 0.001)
	var i: int = 0
	while i < _crumbles.size():
		var c: Array = _crumbles[i]
		c[2] += delta
		var p: float = clampf(c[2] / duration, 0.0, 1.0)
		if p >= 1.0:
			_crumble_mm.set_instance_transform(c[0], HIDDEN)
			_crumbles.remove_at(i)
			continue
		var k: float = config.crumble_start_scale * (1.0 - p * p)
		_crumble_mm.set_instance_transform(c[0], Transform3D(Basis.from_scale(Vector3(1.0, k, 1.0)), c[1]))
		i += 1
	if _crumbles.is_empty() and _clock > _dust_until:
		set_process(false)


## Number of chunk mesh instances (tests).
func chunk_count() -> int:
	return _chunks.size()


## The block mesh of a chunk (null when it holds no dirt).
func chunk_mesh(chunk: Vector2i) -> ArrayMesh:
	var mi: MeshInstance3D = _chunks.get(chunk, null)
	return mi.mesh as ArrayMesh if mi != null else null


## Crumbles running right now (tests).
func crumbling() -> int:
	return _crumbles.size()


## Rebuilds one chunk's block mesh from the map data. Returns the build time in microseconds.
func rebuild_chunk(chunk: Vector2i) -> int:
	var started: int = Time.get_ticks_usec()
	var mesh: ArrayMesh = _builder.build_dirt_chunk(map_loader.data, dirt_walls.chunk_rect(chunk), map_loader.world_config)
	var mi: MeshInstance3D = _chunks.get(chunk, null)
	if mesh == null:
		if mi != null:
			mi.mesh = null
		return Time.get_ticks_usec() - started
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "DirtChunk_%d_%d" % [chunk.x, chunk.y]
		mi.material_override = map_loader.surface_material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_chunks[chunk] = mi
	mi.mesh = mesh
	rebuilds += 1
	return Time.get_ticks_usec() - started


func _on_map_built(map: MapData) -> void:
	for mi: MeshInstance3D in _chunks.values():
		mi.free()
	_chunks.clear()
	_crumbles.clear()
	for i in _crumble_mm.instance_count:
		_crumble_mm.set_instance_transform(i, HIDDEN)
	rebuilds = 0
	_apply_palette()
	if dirt_walls == null:
		return
	var chunks: Dictionary[Vector2i, bool] = {}
	for y in map.height:
		for x in map.width:
			if map.type_at(Vector2i(x, y)) == MapLegend.DIRT:
				chunks[dirt_walls.chunk_of(Vector2i(x, y))] = true
	for chunk: Vector2i in chunks:
		rebuild_chunk(chunk)


func _on_dirt_destroyed(_map_id: StringName, cell: Vector2i, _cause: StringName) -> void:
	if dirt_walls == null:
		return
	for chunk: Vector2i in _touched_chunks([cell]):
		rebuild_chunk(chunk)
	_start_crumble(cell)
	_spawn_dust(cell)


func _on_dirt_restored(cells: Array[Vector2i]) -> void:
	if dirt_walls == null:
		return
	for chunk: Vector2i in _touched_chunks(cells):
		rebuild_chunk(chunk)


func _touched_chunks(cells: Array[Vector2i]) -> Dictionary[Vector2i, bool]:
	var out: Dictionary[Vector2i, bool] = {}
	for cell in cells:
		out[dirt_walls.chunk_of(cell)] = true
		for step in STEPS:
			if dirt_walls.is_dirt(cell + step):
				out[dirt_walls.chunk_of(cell + step)] = true
	return out


func _start_crumble(cell: Vector2i) -> void:
	var slot: int = _next_crumble
	_next_crumble = (_next_crumble + 1) % _crumble_mm.instance_count
	for i in _crumbles.size():
		if _crumbles[i][0] == slot:
			_crumbles.remove_at(i)
			break
	var centre: Vector3 = map_loader.cell_to_world(cell)
	_crumble_mm.set_instance_transform(slot, Transform3D(Basis.from_scale(Vector3(1.0, config.crumble_start_scale, 1.0)), centre))
	_crumbles.append([slot, centre, 0.0])
	set_process(true)


func _spawn_dust(cell: Vector2i) -> void:
	var centre: Vector3 = map_loader.cell_to_world(cell)
	var half: float = map_loader.world_config.cell_size * 0.5
	var y: float = map_loader.world_config.wall_height * config.fragment_start_height
	var columns: int = maxi(config.fragment_chars.length(), 1)
	for i in config.fragments_per_eat:
		var offset := Vector3(_rng.randf_range(-half, half), y * _rng.randf_range(0.85, 1.0), _rng.randf_range(-half, half))
		var dir := Vector2(offset.x, offset.z).normalized() * config.fragment_spread * _rng.randf_range(0.3, 1.0)
		var size: float = config.fragment_size * _rng.randf_range(0.7, 1.3)
		_dust_mm.set_instance_transform(_next_dust, Transform3D(Basis.from_scale(Vector3.ONE * size), centre + offset))
		_dust_mm.set_instance_custom_data(_next_dust, Color(_clock, float(_rng.randi() % columns), dir.x, dir.y))
		_next_dust = (_next_dust + 1) % _dust_mm.instance_count
	_dust_until = _clock + config.fragment_lifetime
	set_process(true)


func _apply_palette() -> void:
	var material := map_loader.surface_material as ShaderMaterial if map_loader != null else null
	if material == null:
		return
	material.set_shader_parameter(&"dirt_dark", Vector3(config.palette_dark.r, config.palette_dark.g, config.palette_dark.b))
	material.set_shader_parameter(&"dirt_bright", Vector3(config.palette_bright.r, config.palette_bright.g, config.palette_bright.b))
	material.set_shader_parameter(&"dirt_variation", config.variation)


func _build_pools() -> void:
	var world: WorldConfig = map_loader.world_config if map_loader != null and map_loader.world_config != null else WorldConfig.new()
	_crumble_mm = MultiMesh.new()
	_crumble_mm.transform_format = MultiMesh.TRANSFORM_3D
	_crumble_mm.mesh = _builder.build_dirt_block(world, config.crumble_start_scale)
	_crumble_mm.instance_count = maxi(config.crumble_capacity, 1)
	for i in _crumble_mm.instance_count:
		_crumble_mm.set_instance_transform(i, HIDDEN)
	var crumble := MultiMeshInstance3D.new()
	crumble.name = "Crumble"
	crumble.multimesh = _crumble_mm
	if map_loader != null:
		crumble.material_override = map_loader.surface_material
	crumble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crumble.custom_aabb = AABB(Vector3(-1.0e4, -10.0, -1.0e4), Vector3(2.0e4, 20.0, 2.0e4))
	add_child(crumble)

	_dust_viewport = SubViewport.new()
	_dust_viewport.name = "DustAtlas"
	_dust_viewport.transparent_bg = true
	_dust_viewport.disable_3d = true
	_dust_viewport.gui_disable_input = true
	var columns: int = maxi(config.fragment_chars.length(), 1)
	_dust_viewport.size = Vector2i(columns * config.fragment_tile_px, config.fragment_tile_px)
	_dust_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_dust_viewport)
	var painter := InkTrailView.InkPainter.new()
	var font := SystemFont.new()
	font.font_names = config.fragment_font_names
	painter.font = font
	painter.glyphs = config.fragment_chars
	painter.tile = config.fragment_tile_px
	painter.font_px = config.fragment_font_px
	_dust_viewport.add_child(painter)
	var quad := QuadMesh.new()
	quad.size = Vector2(QUAD_EXTENT, QUAD_EXTENT)
	_dust_mm = MultiMesh.new()
	_dust_mm.transform_format = MultiMesh.TRANSFORM_3D
	_dust_mm.use_custom_data = true
	_dust_mm.mesh = quad
	_dust_mm.instance_count = maxi(config.fragment_capacity, 1)
	for i in _dust_mm.instance_count:
		_dust_mm.set_instance_custom_data(i, Color(-1000.0, 0.0, 0.0, 0.0))
	_dust_material = ShaderMaterial.new()
	_dust_material.shader = load(DUST_SHADER) as Shader
	_dust_material.set_shader_parameter(&"dust_atlas", _dust_viewport.get_texture())
	_dust_material.set_shader_parameter(&"atlas_cols", float(columns))
	_dust_material.set_shader_parameter(&"lifetime", config.fragment_lifetime)
	_dust_material.set_shader_parameter(&"rise", config.fragment_rise)
	_dust_material.set_shader_parameter(&"gravity", config.fragment_gravity)
	_dust_material.set_shader_parameter(&"dust_color", Vector3(config.fragment_color.r, config.fragment_color.g, config.fragment_color.b))
	_dust_material.set_shader_parameter(&"rim_color", Vector3(config.fragment_rim.r, config.fragment_rim.g, config.fragment_rim.b))
	var dust := MultiMeshInstance3D.new()
	dust.name = "Dust"
	dust.multimesh = _dust_mm
	dust.material_override = _dust_material
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.custom_aabb = AABB(Vector3(-1.0e4, -10.0, -1.0e4), Vector3(2.0e4, 20.0, 2.0e4))
	add_child(dust)
