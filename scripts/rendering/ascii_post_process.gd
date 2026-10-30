class_name AsciiPostProcess
extends CanvasLayer
## Full-screen ASCII post-process. Owns a ColorRect (child "Screen") that carries the ascii_post
## shader and feeds it everything it needs:
##  - the SDF glyph atlas (GlyphAtlas, baked once at boot; shared with the overlay),
##  - the palette LUT and glyph ramp LUT,
##  - per-frame view data (player position on screen, world position of the screen origin),
##  - the global shader parameters the world materials read (player position, light, look).
## The 3D world renders data, not colour (see shaders/world_encode.gdshader).

## Emitted once the atlas, LUTs and uniforms are in place.
signal ready_to_draw

const RAMP_LUT_WIDTH := 16
const RAMP_LUT_HEIGHT := 8
## The last texel of a ramp LUT row holds the ramp length.
const RAMP_LEN_TEXEL := RAMP_LUT_WIDTH - 1

@export var config: AsciiConfig
@export var palette: PaletteConfig
@export var light_config: LightConfig
@export var hazard_fx: HazardFxConfig
@export var glyph_fx: GlyphFxConfig
@export var display_config: DisplayConfig
@export var camera_rig: CameraRig
@export var player: Node3D

@onready var _screen: ColorRect = $Screen

## The shared SDF atlas (valid once `ready_to_draw` was emitted).
var atlas: GlyphAtlas = GlyphAtlas.new()

var _material: ShaderMaterial
var _cell: Vector2 = Vector2.ZERO
var _world_per_px: float = 0.0
var _ready_to_draw: bool = false


func _ready() -> void:
	if config == null:
		config = AsciiConfig.new()
	if palette == null:
		palette = PaletteConfig.new()
	if light_config == null:
		light_config = LightConfig.new()
	if hazard_fx == null:
		hazard_fx = HazardFxConfig.new()
	if glyph_fx == null:
		glyph_fx = GlyphFxConfig.new()
	if display_config == null:
		display_config = DisplayConfig.new()
	_material = _screen.material as ShaderMaterial
	_screen.visible = false
	set_process(false)
	await atlas.bake(self, config)
	_apply_tables(palette)
	_apply_static()
	_ready_to_draw = true
	_screen.visible = config.enabled
	set_process(true)
	get_viewport().size_changed.connect(_apply_static)
	SignalBus.run_started.connect(_on_run_started)
	ready_to_draw.emit()


func _process(_delta: float) -> void:
	_apply_view()


## Enables or disables the effect at runtime (debug toggle; the raw render holds encoded data).
func set_enabled(value: bool) -> void:
	config.enabled = value
	_screen.visible = value and _ready_to_draw


## Glyph cell size in screen pixels at the current window size.
func cell_px() -> Vector2:
	return _cell


## World units per screen pixel (orthographic equivalent).
func world_per_px() -> float:
	return _world_per_px


func _on_run_started(run_index: int) -> void:
	_apply_tables(palette.for_run(run_index))


## Palette LUT, ramp LUT and the colours that come from the palette.
func _apply_tables(pal: PaletteConfig) -> void:
	_material.set_shader_parameter("palette_lut", pal.build_lut())
	_material.set_shader_parameter("ramp_lut", _build_ramp_lut())
	_material.set_shader_parameter("bg_centre", _rgb(pal.bg_centre))
	_material.set_shader_parameter("bg_edge", _rgb(pal.bg_edge))
	_material.set_shader_parameter("light_tint", _rgb(pal.light_tint))


## Everything that only changes with the window size, the camera or the configuration.
func _apply_static() -> void:
	var factor: float = display_config.scale_for(get_viewport())
	_cell = Vector2(DisplayConfig.px(config.cell_size.x, factor), DisplayConfig.px(config.cell_size.y, factor))
	atlas.apply_to(_material)
	_material.set_shader_parameter("cell_px", _cell)
	_material.set_shader_parameter("morph_band", config.morph_band)
	_material.set_shader_parameter("scale_dip", glyph_fx.morph_scale_dip)
	_material.set_shader_parameter("glow_boost", glyph_fx.morph_glow_boost)
	_material.set_shader_parameter("edge_near", config.edge_soft_near)
	_material.set_shader_parameter("edge_far", config.edge_soft_far)
	_material.set_shader_parameter("dof_px", config.dof_start_cells * _cell.y)
	_material.set_shader_parameter("dof_slide", config.dof_color_slide)
	_material.set_shader_parameter("glow_radius", config.glow_radius)
	_material.set_shader_parameter("glow_strength", config.glow_strength)
	_material.set_shader_parameter("bloom_on", config.bloom_enabled)
	_material.set_shader_parameter("bloom_sigma_px", config.bloom_radius_cells * _cell.y * 0.5)
	_material.set_shader_parameter("bloom_strength", config.bloom_strength)
	_material.set_shader_parameter("wall_rim", config.wall_rim_strength)
	_material.set_shader_parameter("emissive_weight", config.glow_weights)
	_material.set_shader_parameter("vignette_strength", config.vignette_strength)
	_material.set_shader_parameter("vignette_radius", config.vignette_radius)
	_material.set_shader_parameter("mem_cap", config.memory_density_cap)
	_material.set_shader_parameter("mem_mix", config.memory_type_mix)
	_material.set_shader_parameter("light_tint_strength", light_config.light_tint_strength)
	_material.set_shader_parameter("bg_pool", light_config.bg_pool_strength)
	_material.set_shader_parameter("light_px", Vector2(light_config.light_inner, light_config.light_outer) * _cell.y)
	_material.set_shader_parameter("corrupt_warp_amp", hazard_fx.corrupt_warp_amp)
	_material.set_shader_parameter("corrupt_period", hazard_fx.corrupt_warp_period)
	_material.set_shader_parameter("corrupt_hue_hz", hazard_fx.corrupt_hue_hz)
	_world_per_px = 0.0
	_apply_view()


## Per-frame view data; the world-unit conversions are refreshed when the scale changed.
func _apply_view() -> void:
	if camera_rig == null or camera_rig.camera == null:
		return
	var cam: Camera3D = camera_rig.camera
	var view: Vector2 = get_viewport().get_visible_rect().size
	var wpp: float = _world_units_per_px(cam, view)
	var focus := Vector2(cam.global_position.x, cam.global_position.z)
	_material.set_shader_parameter("view_origin", focus - 0.5 * view * wpp)
	_material.set_shader_parameter("world_per_px", wpp)
	var target: Vector3 = player.global_position if player != null else cam.global_position
	_material.set_shader_parameter("player_px", cam.unproject_position(target))
	RenderingServer.global_shader_parameter_set(&"player_pos", Vector2(target.x, target.z))
	if not is_equal_approx(wpp, _world_per_px):
		_world_per_px = wpp
		var cell_world: float = _cell.y * wpp
		RenderingServer.global_shader_parameter_set(&"light_params", Vector4(
				light_config.light_inner * cell_world, light_config.light_outer * cell_world,
				light_config.light_ambient, 0.0))
		RenderingServer.global_shader_parameter_set(&"look_params", Vector4(
				config.hue_noise_scale, config.hue_noise_amp, config.hue_noise_detail, config.height_amp))


func _world_units_per_px(cam: Camera3D, view: Vector2) -> float:
	var vertical: float = cam.size
	if cam.projection != Camera3D.PROJECTION_ORTHOGONAL:
		vertical = 2.0 * absf(cam.position.z) * tan(deg_to_rad(cam.fov) * 0.5)
	return vertical / maxf(view.y, 1.0)


## One glyph index per ramp step, row per material id; the last texel holds the ramp length.
func _build_ramp_lut() -> ImageTexture:
	var ramps: Dictionary[int, String] = {
		MaterialIds.WALL: config.ramp_wall, MaterialIds.FLOOR: config.ramp_floor, MaterialIds.ITEM: config.ramp_item,
		MaterialIds.SPIKES: config.ramp_spikes, MaterialIds.CORRUPT: config.ramp_corruption,
	}
	var img := Image.create(RAMP_LUT_WIDTH, RAMP_LUT_HEIGHT, false, Image.FORMAT_R8)
	for id: int in ramps:
		var ramp: String = ramps[id]
		var length: int = mini(ramp.length(), RAMP_LEN_TEXEL)
		for i in length:
			img.set_pixel(i, id, Color(float(atlas.index_of(ramp[i])) / 255.0, 0.0, 0.0))
		img.set_pixel(RAMP_LEN_TEXEL, id, Color(float(length) / 255.0, 0.0, 0.0))
	return ImageTexture.create_from_image(img)


static func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
