class_name CannonBallView
extends Node3D
## Draws the cannon balls (task-073): ONE MultiMesh (shaders/cannon_ball.gdshader) of camera-facing glyph quads for
## every ball and its short trail (CannonConfig.trail_length glyphs behind it along the straight flight since the last
## bounce, so a trail never pokes through a wall). The glyphs are rasterised once into a tiny atlas. Per frame the live
## balls are packed into the first instances and visible_instance_count cut to them (no per-ball nodes, nothing drawn
## when no ball flies). Reads CannonBalls; never writes data.

const SHADER: String = "res://shaders/cannon_ball.gdshader"
const QUAD_EXTENT: float = 2.0
## Size and opacity of trail glyph k (k = 1 nearest) relative to the ball: (1 - k * FALLOFF).
const TRAIL_FALLOFF: float = 0.22

@export var config: CannonConfig
@export var balls: CannonBalls

var _mm: MultiMesh
var _material: ShaderMaterial
var _viewport: SubViewport
## Glyph quads drawn in the last frame (tests).
var drawn: int = 0


func _ready() -> void:
	if config == null:
		config = CannonConfig.new()
	_build()


func _process(_delta: float) -> void:
	if balls == null:
		return
	if balls.active_count() <= 0:
		if _mm.visible_instance_count != 0:
			_mm.visible_instance_count = 0
		drawn = 0
		return
	var n: int = 0
	var cap: int = _mm.instance_count
	var trail: int = mini(config.trail_length, maxi(config.ball_chars.length() - 1, 0))
	for i in balls.capacity():
		if balls.state_of(i) == CannonBalls.State.FREE:
			continue
		var a: float = balls.alpha_of(i)
		var p: Vector3 = balls.position_of(i)
		var size: float = balls.size_of(i)
		var v: Vector3 = balls.velocity_of(i)
		var back: Vector3 = -v.normalized() if v.length_squared() > 0.0 else Vector3.ZERO
		if n < cap:
			_put(n, p, size, config.ball_color, a, 0.0, 1.0)
			n += 1
		var room: float = balls.straight_of(i)
		for k in range(1, trail + 1):
			var dist: float = config.trail_spacing * size / maxf(config.ball_size, 0.001) * k
			if dist > room or n >= cap:
				break
			var f: float = maxf(1.0 - TRAIL_FALLOFF * k, 0.1)
			_put(n, p + back * dist, size * f, config.trail_color, a * f, float(k), 0.4)
			n += 1
	_mm.visible_instance_count = n
	drawn = n


func _put(slot: int, pos: Vector3, size: float, color: Color, alpha: float, column: float, glow: float) -> void:
	_mm.set_instance_transform(slot, Transform3D(Basis.from_scale(Vector3.ONE * size), pos))
	_mm.set_instance_color(slot, color)
	_mm.set_instance_custom_data(slot, Color(alpha, column, glow, 0.0))


func _build() -> void:
	var cols: int = maxi(config.ball_chars.length(), 1)
	_viewport = SubViewport.new()
	_viewport.name = "BallAtlas"
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	_viewport.size = Vector2i(cols * config.glyph_tile_px, config.glyph_tile_px)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	var painter := InkTrailView.InkPainter.new()
	var font := SystemFont.new()
	font.font_names = config.glyph_font_names
	painter.font = font
	painter.glyphs = config.ball_chars
	painter.tile = config.glyph_tile_px
	painter.font_px = config.glyph_font_px
	_viewport.add_child(painter)
	var quad := QuadMesh.new()
	quad.size = Vector2(QUAD_EXTENT, QUAD_EXTENT)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.mesh = quad
	var trail: int = mini(config.trail_length, maxi(config.ball_chars.length() - 1, 0))
	_mm.instance_count = maxi(config.capacity, 1) * (1 + trail)
	_mm.visible_instance_count = 0
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER) as Shader
	_material.set_shader_parameter(&"ball_atlas", _viewport.get_texture())
	_material.set_shader_parameter(&"atlas_cols", float(cols))
	_material.set_shader_parameter(&"rim_color", Vector3(config.ball_rim.r, config.ball_rim.g, config.ball_rim.b))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Balls"
	instance.multimesh = _mm
	instance.material_override = _material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3(-1.0e4, -10.0, -1.0e4), Vector3(2.0e4, 20.0, 2.0e4))
	add_child(instance)
