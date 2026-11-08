class_name GlyphStormView
extends Node3D
## Presentation of the glyph storm (task-030, Spike B moment 4): the glyphs of the floor and walls around the player lift
## off at once, swirl around the player for a couple of seconds and settle back. It starts on SignalBus.origin_struck
## (the moment something about the player was proven false) and on SignalBus.glyph_storm_requested, so any later moment
## can ask for one. It never pauses anything and never writes data.
## Potato budget: ONE MultiMesh (shaders/glyph_storm.gdshader, one draw call, hidden while no storm runs) built ONCE with
## `StormConfig.glyph_cap` instances and no per-instance data: the shader derives start cell, timing and orbit of each
## instance from its id and a seed, reading the map from `source_map` (one texel per cell, built at map build) and the reveal
## mask. So a storm starts with a handful of uniforms (measured: `last_start_usec`), the shader is compiled during the
## first frames after the load (warm-up) and nothing is allocated per frame. Processing runs only while a storm lasts.
## The floor and walls within the storm dim through the `storm_zone` uniform of the world material while their glyphs are away.

const STORM_SHADER: String = "res://shaders/glyph_storm.gdshader"
const QUAD_EXTENT: float = 2.0
## Half the world: the bounding box never culls the storm (its places are computed in the shader).
const CULL_HALF_EXTENT: float = 500.0
## Source map values (see the shader).
const SOURCE_FLOOR: int = 128
const SOURCE_WALL: int = 255
## Frames the quads are drawn with no storm running, so the driver compiles the shader before the first storm.
const WARM_UP_FRAMES: int = 2

@export var config: StormConfig
@export var fx_config: GlyphFxConfig
@export var player: Player
@export var map_loader: MapLoader
@export var world: WorldConfig
## The glyph-surface material of the world: its `storm_zone` uniform dims the surroundings while the glyphs are away.
@export var surface_material: ShaderMaterial

## Microseconds the last start_storm() call took on the CPU (the "no hitch" figure).
var last_start_usec: int = 0
## Storms started so far.
var storms_started: int = 0

var _active: bool = false
var _t: float = 0.0
var _duration: float = 0.0
var _radius: float = 0.0
var _centre := Vector3.ZERO
var _viewport: SubViewport
var _painter: PlayerGlyphView.AtlasPainter
var _multimesh: MultiMesh
var _instance: MultiMeshInstance3D
var _material: ShaderMaterial
var _source_texture: ImageTexture
var _rng := RandomNumberGenerator.new()
var _atlas_grid: Vector2 = Vector2.ONE
var _zone_centre := Vector2.ZERO
var _zone_radius: float = 1.0
var _dim: float = 0.0


func _ready() -> void:
	top_level = true
	if config == null:
		config = StormConfig.new()
	if fx_config == null:
		fx_config = GlyphFxConfig.new()
	if world == null:
		world = WorldConfig.new()
	_rng.randomize()
	_build_atlas()
	_build_instance()
	_build_source_map()
	set_process(false)
	if map_loader != null:
		map_loader.map_built.connect(_on_map_built)
	SignalBus.origin_struck.connect(_on_origin_struck)
	SignalBus.glyph_storm_requested.connect(_on_storm_requested)
	_warm_up()


func _process(delta: float) -> void:
	if not _active:
		set_process(false)
		return
	_t += delta
	if _t >= _duration:
		_finish()
		return
	_material.set_shader_parameter(&"storm_t", _t)
	if player != null:
		_material.set_shader_parameter(&"storm_follow", player.global_position)
	_set_dim(_dim_at(_t))


## True from the start of a storm until its last glyph is back on the ground.
func is_active() -> bool:
	return _active


## Seconds since the running storm started (0 when none runs).
func elapsed() -> float:
	return _t if _active else 0.0


## Instances drawn by the running (or last) storm.
func glyph_count() -> int:
	return _multimesh.visible_instance_count if _multimesh != null else 0


## Instances allocated up front.
func capacity() -> int:
	return _multimesh.instance_count if _multimesh != null else 0


## 0..1 amount the surroundings are dimmed by right now.
func dim_amount() -> float:
	return _dim


## Starts (or restarts) a storm around `centre`. `radius` / `duration` <= 0 use the config; `tint` with alpha 0 the default.
## A storm already running restarts from its beginning with a new seed; the dim of the surroundings carries on smoothly.
func start_storm(centre: Vector3, radius: float = 0.0, duration: float = 0.0, tint: Color = Color(0, 0, 0, 0)) -> void:
	var began: int = Time.get_ticks_usec()
	_radius = radius if radius > 0.0 else config.radius
	_duration = duration if duration > 0.0 else config.duration
	_centre = centre
	var flight: float = _duration * (1.0 - config.stagger_fraction)
	var stagger: float = _duration - flight
	var area: float = (_radius * _radius - config.inner_radius * config.inner_radius) / maxf(config.radius * config.radius - config.inner_radius * config.inner_radius, 0.01)
	var used: int = clampi(roundi(config.glyph_count * area), 1, capacity())
	var colour: Color = tint if tint.a > 0.0 else config.default_tint
	_t = 0.0
	_zone_centre = Vector2(centre.x, centre.z)
	_zone_radius = _radius + config.dim_radius_extra
	_material.set_shader_parameter(&"storm_centre", Vector4(centre.x, centre.y, centre.z, _radius))
	_material.set_shader_parameter(&"storm_follow", centre)
	_material.set_shader_parameter(&"storm_t", 0.0)
	_material.set_shader_parameter(&"flight", flight)
	_material.set_shader_parameter(&"stagger", stagger)
	_material.set_shader_parameter(&"storm_seed", _rng.randi() & 0x3fffffff)
	_material.set_shader_parameter(&"used", used)
	_material.set_shader_parameter(&"storm_tint", Vector3(colour.r, colour.g, colour.b))
	_multimesh.visible_instance_count = used
	_instance.visible = true
	_active = true
	storms_started += 1
	set_process(true)
	last_start_usec = Time.get_ticks_usec() - began


func _on_origin_struck(id: StringName) -> void:
	if player == null:
		return
	start_storm(player.global_position, 0.0, 0.0, config.nature_tints.get(id, config.default_tint))


func _on_storm_requested(centre: Vector3, radius: float, duration: float, tint: Color) -> void:
	start_storm(centre, radius, duration, tint)


func _on_map_built(_data: MapData) -> void:
	_build_source_map()


func _finish() -> void:
	_active = false
	_t = 0.0
	_instance.visible = false
	_material.set_shader_parameter(&"storm_t", -1.0)
	_set_dim(0.0)
	set_process(false)


## The 0..1 dim envelope of the surroundings at `t` seconds: eased in, held, eased out over the last dim_out seconds.
func _dim_at(t: float) -> float:
	var rise: float = clampf(t / maxf(config.dim_in, 0.001), 0.0, 1.0)
	var fall: float = clampf((_duration - t) / maxf(config.dim_out, 0.001), 0.0, 1.0)
	return rise * rise * (3.0 - 2.0 * rise) * fall * fall * (3.0 - 2.0 * fall)


func _set_dim(amount: float) -> void:
	_dim = amount
	if surface_material != null:
		surface_material.set_shader_parameter(&"storm_zone", Vector4(_zone_centre.x, _zone_centre.y, _zone_radius, config.dim_amount * amount))


## Draws the (collapsed) quads for a few frames so the shader is compiled before the first storm, then hides them.
func _warm_up() -> void:
	_instance.visible = true
	for i in WARM_UP_FRAMES:
		await get_tree().process_frame
	if not _active:
		_instance.visible = false


# ---------------------------------------------------------------------------------------------------------------------
# Source map, atlas and instance (all built once)


## One texel per map cell: 0 void, 128 floor, 255 wall. The shader only lifts glyphs from cells that exist.
func _build_source_map() -> void:
	if map_loader == null or map_loader.data.is_empty():
		return
	var data: MapData = map_loader.data
	var image := Image.create(data.width, data.height, false, Image.FORMAT_R8)
	for y in data.height:
		for x in data.width:
			var type: StringName = data.type_at(Vector2i(x, y))
			var value: int = 0
			if type == MapLegend.WALL or type == MapLegend.DIRT:
				value = SOURCE_WALL
			elif type != MapLegend.VOID:
				value = SOURCE_FLOOR
			image.set_pixel(x, y, Color8(value, 0, 0))
	if _source_texture == null:
		_source_texture = ImageTexture.create_from_image(image)
	else:
		_source_texture.set_image(image)
	_material.set_shader_parameter(&"source_map", _source_texture)
	_material.set_shader_parameter(&"map_params", Vector4(data.width, data.height, world.cell_size, world.wall_height))


func _build_atlas() -> void:
	var glyphs := PackedStringArray()
	# Slot order is part of the shader contract: floor glyphs, wall glyphs, storm glyphs.
	for text in [config.floor_source_glyphs, config.wall_source_glyphs, config.storm_glyphs]:
		for ch in text:
			glyphs.append(ch)
	var cols: int = ceili(sqrt(float(glyphs.size())))
	var rows: int = ceili(float(glyphs.size()) / float(cols))
	_viewport = SubViewport.new()
	_viewport.name = "StormAtlas"
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	_viewport.size = Vector2i(cols, rows) * fx_config.atlas_tile_px
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	_painter = PlayerGlyphView.AtlasPainter.new()
	_painter.name = "Painter"
	var font := SystemFont.new()
	font.font_names = config.font_names
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.font_weight = config.font_weight
	_painter.font = font
	_painter.tile = fx_config.atlas_tile_px
	_painter.font_px = int(fx_config.atlas_tile_px * fx_config.font_fill)
	_painter.glyphs = glyphs
	_painter.cols = cols
	_viewport.add_child(_painter)
	_atlas_grid = Vector2(cols, rows)


func _build_instance() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(QUAD_EXTENT, QUAD_EXTENT)
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = false
	_multimesh.use_custom_data = false
	_multimesh.mesh = quad
	_multimesh.instance_count = config.glyph_cap
	_multimesh.visible_instance_count = config.glyph_count
	_material = ShaderMaterial.new()
	_material.shader = load(STORM_SHADER) as Shader
	_material.render_priority = 0
	_material.set_shader_parameter(&"glyph_atlas", _viewport.get_texture())
	_material.set_shader_parameter(&"atlas_grid", _atlas_grid)
	_material.set_shader_parameter(&"glyph_fill", config.glyph_fill)
	_material.set_shader_parameter(&"outline_color", config.outline_color)
	_material.set_shader_parameter(&"outline_width", config.outline_width)
	_material.set_shader_parameter(&"inner_radius", config.inner_radius)
	_material.set_shader_parameter(&"lift_frac", config.lift_fraction)
	_material.set_shader_parameter(&"settle_frac", config.settle_fraction)
	_material.set_shader_parameter(&"swirl_turns", config.swirl_turns)
	_material.set_shader_parameter(&"inner_boost", config.inner_turn_boost)
	_material.set_shader_parameter(&"swirl_dir", config.swirl_direction)
	_material.set_shader_parameter(&"spiral_out", config.spiral_out)
	_material.set_shader_parameter(&"follow", config.follow)
	_material.set_shader_parameter(&"wobble", config.wobble)
	_material.set_shader_parameter(&"spin_amount", config.spin_amount)
	_material.set_shader_parameter(&"peak_height", config.peak_height)
	_material.set_shader_parameter(&"height_var", config.height_variation)
	_material.set_shader_parameter(&"ground_lift", config.ground_lift)
	_material.set_shader_parameter(&"size_ground", config.size_ground)
	_material.set_shader_parameter(&"size_air", config.size_air)
	_material.set_shader_parameter(&"size_var", config.size_variation)
	_material.set_shader_parameter(&"pop", config.pop)
	_material.set_shader_parameter(&"floor_n", config.floor_source_glyphs.length())
	_material.set_shader_parameter(&"wall_n", config.wall_source_glyphs.length())
	_material.set_shader_parameter(&"storm_n", config.storm_glyphs.length())
	_material.set_shader_parameter(&"floor_color", _rgb(config.floor_color))
	_material.set_shader_parameter(&"wall_color", _rgb(config.wall_color))
	_material.set_shader_parameter(&"air_color", _rgb(config.air_color))
	_material.set_shader_parameter(&"tint_mix", config.tint_mix)
	_material.set_shader_parameter(&"memory_bright", config.memory_brightness)
	_material.set_shader_parameter(&"glow_strength", config.glow_strength)
	_material.set_shader_parameter(&"air_alpha", config.air_alpha)
	_material.set_shader_parameter(&"storm_t", -1.0)
	_instance = MultiMeshInstance3D.new()
	_instance.name = "Storm"
	_instance.multimesh = _multimesh
	_instance.material_override = _material
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_instance.custom_aabb = AABB(Vector3.ONE * -CULL_HALF_EXTENT, Vector3.ONE * CULL_HALF_EXTENT * 2.0)
	_instance.visible = false
	add_child(_instance)


func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
