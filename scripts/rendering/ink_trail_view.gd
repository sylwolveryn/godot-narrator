class_name InkTrailView
extends Node3D
## Ink trail behind the player (task-057): while the player moves, a small ink glyph is dropped every
## AvatarFxConfig.trail_spacing world units; it spreads a little and fades out over trail_lifetime seconds. ONE
## MultiMesh (shaders/ink_trail.gdshader), a ring buffer of trail_capacity drops: the CPU writes one instance per
## drop, the fade runs in the shader. The ink glyphs are rasterised once (and again when the DB changes them).
## Values come from the DB table avatar_fx (GameDatabase.tables_loaded). Presentation only.
## Task-104: SignalBus.trail_tint_changed (DeathMarks) tints the NEW drops crimson (blood) or dark purple (void) via
## the MultiMesh instance colour (a = tint share); drops already on the floor keep the colour they were dropped with.

const SHADER: String = "res://shaders/ink_trail.gdshader"
## Edge of the quad mesh; the instance scale is the half-size.
const QUAD_EXTENT: float = 2.0


class InkPainter extends Node2D:
	var font: Font
	var glyphs: String = ""
	var tile: int = 48
	var font_px: int = 40

	func _draw() -> void:
		for i in glyphs.length():
			var code: int = glyphs.unicode_at(i)
			var size: Vector2 = font.get_char_size(code, font_px)
			var pos := Vector2(i * tile + (tile - size.x) * 0.5, tile * 0.5 + (font.get_ascent(font_px) - font.get_descent(font_px)) * 0.5)
			font.draw_char(get_canvas_item(), pos, code, font_px, Color.WHITE)


@export var config: AvatarFxConfig
@export var database: GameDatabase
@export var player: Player
@export var run_manager: RunManager
## Tint colours of the trail (task-104); null uses the DeathMarksConfig defaults.
@export var marks_config: DeathMarksConfig

var _fx: AvatarFxConfig
var _multimesh: MultiMesh
var _material: ShaderMaterial
var _viewport: SubViewport
var _painter: InkPainter
var _rng := RandomNumberGenerator.new()
var _clock: float = 0.0
var _next: int = 0
var _travelled: float = 0.0
var _last_position: Vector3 = Vector3.INF
var _drops: int = 0
## Instance colour of new drops: rgb tint, a = share of the tint (0 = the normal ink).
var _tint: Color = Color(1.0, 1.0, 1.0, 0.0)


func _ready() -> void:
	if config == null:
		config = AvatarFxConfig.new()
	_rng.randomize()
	_build()
	apply(config.from_tables(database.tables) if database != null else config)
	if database != null:
		database.tables_loaded.connect(func(tables: Dictionary) -> void: apply(config.from_tables(tables)))
	if marks_config == null:
		marks_config = DeathMarksConfig.new()
	SignalBus.run_started.connect(func(_i: int) -> void: clear())
	SignalBus.trail_tint_changed.connect(set_tint)


## Tints the drops dropped from now on: &"blood", &"void" or &"" (the normal ink).
func set_tint(kind: StringName) -> void:
	match kind:
		DeathMarks.TINT_BLOOD:
			_tint = Color(marks_config.trail_blood_ink, 1.0)
		DeathMarks.TINT_VOID:
			_tint = Color(marks_config.trail_void_ink, 1.0)
		_:
			_tint = Color(1.0, 1.0, 1.0, 0.0)


## Instance colour of the new drops (tests).
func current_tint() -> Color:
	return _tint


func _process(delta: float) -> void:
	_clock += delta
	_material.set_shader_parameter(&"now", _clock)
	if player == null or not _fx.trail_enabled or _fx.trail_chars == "":
		return
	var pos: Vector3 = player.global_position
	if _last_position == Vector3.INF or not _playing():
		_last_position = pos
		return
	_travelled += Vector2(pos.x - _last_position.x, pos.z - _last_position.z).length()
	_last_position = pos
	if _travelled >= _fx.trail_spacing:
		_travelled = fmod(_travelled, maxf(_fx.trail_spacing, 0.001))
		_drop(pos)


## Applies a look: rasterises the trail glyphs and pushes the colours and timings.
func apply(fx: AvatarFxConfig) -> void:
	_fx = fx
	var chars: String = fx.trail_chars.substr(0, fx.trail_max_chars)
	_painter.glyphs = chars
	_painter.queue_redraw()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_material.set_shader_parameter(&"lifetime", fx.trail_lifetime)
	_material.set_shader_parameter(&"spread", fx.trail_spread)
	_material.set_shader_parameter(&"ink_color", Vector3(fx.trail_color.r, fx.trail_color.g, fx.trail_color.b))
	_material.set_shader_parameter(&"rim_color", Vector3(fx.trail_rim.r, fx.trail_rim.g, fx.trail_rim.b))


## Number of drops spawned since the last clear (tests).
func drop_count() -> int:
	return _drops


## Removes every drop (new run).
func clear() -> void:
	for i in _multimesh.instance_count:
		_multimesh.set_instance_custom_data(i, Color(-1000.0, 0.0, 0.0, 0.0))
		_multimesh.set_instance_color(i, Color(1.0, 1.0, 1.0, 0.0))
	_travelled = 0.0
	_last_position = Vector3.INF
	_drops = 0


func _playing() -> bool:
	return run_manager == null or run_manager.phase == RunManager.Phase.PLAYING


func _drop(pos: Vector3) -> void:
	var side := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)) * _fx.trail_jitter
	var origin := Vector3(pos.x, _fx.trail_height, pos.z) + side
	_multimesh.set_instance_transform(_next, Transform3D(Basis.from_scale(Vector3.ONE * _fx.trail_size), origin))
	var count: int = mini(_fx.trail_chars.length(), _fx.trail_max_chars)
	_multimesh.set_instance_custom_data(_next, Color(_clock, float(_rng.randi() % maxi(count, 1)), _rng.randf(), _rng.randf()))
	_multimesh.set_instance_color(_next, _tint)
	_next = (_next + 1) % _multimesh.instance_count
	_drops += 1


func _build() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "InkAtlas"
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	_viewport.size = Vector2i(config.trail_max_chars * config.trail_tile_px, config.trail_tile_px)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	_painter = InkPainter.new()
	var font := SystemFont.new()
	font.font_names = config.trail_font_names
	_painter.font = font
	_painter.tile = config.trail_tile_px
	_painter.font_px = config.trail_font_px
	_viewport.add_child(_painter)
	var quad := QuadMesh.new()
	quad.size = Vector2(QUAD_EXTENT, QUAD_EXTENT)
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_custom_data = true
	_multimesh.use_colors = true
	_multimesh.mesh = quad
	_multimesh.instance_count = maxi(config.trail_capacity, 1)
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER) as Shader
	_material.render_priority = 0
	_material.set_shader_parameter(&"ink_atlas", _viewport.get_texture())
	_material.set_shader_parameter(&"atlas_cols", float(config.trail_max_chars))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Drops"
	instance.multimesh = _multimesh
	instance.material_override = _material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Drops are spread over the map; never cull the MultiMesh by its (origin-based) bounds.
	instance.custom_aabb = AABB(Vector3(-1.0e4, -10.0, -1.0e4), Vector3(2.0e4, 20.0, 2.0e4))
	add_child(instance)
	clear()
