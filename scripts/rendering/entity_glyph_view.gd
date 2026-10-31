class_name EntityGlyphView
extends Node3D
## The body of the grown multi-glyph entity (task-017): ONE MultiMesh of camera-facing quads around the heart
## (the identity glyph, drawn by PlayerGlyphView). All motion lives in shaders/glyph_entity.gdshader: the grow moment
## (glyphs gather from around, fly in with stagger, overshoot, spin and a scale pop), the settled bob, the lag when
## walking, the fold back into one glyph, the erosion look and the death burst. The instance buffer is written once
## per identity; a frame only sets a handful of uniforms. PlayerGlyphView drives this node (present / grow / fold /
## burst); it never writes data and sends no signals.

enum State { HIDDEN, GROWING, GROWN, FOLDING }

const ENTITY_SHADER: String = "res://shaders/glyph_entity.gdshader"
const QUAD_EXTENT: float = 2.0
## A grow time far past every glyph's landing: the settled state.
const SETTLED: float = 1000.0
## Half the world: the bounding box of the body never culls it (its place is a uniform, not the node transform).
const CULL_HALF_EXTENT: float = 500.0
## Largest speed (units per second) the trail follows, so a teleport does not fling the body.
const MAX_TRAIL_SPEED: float = 8.0

@export var config: EntityGrowthConfig
@export var fx_config: GlyphFxConfig
@export var player_config: PlayerConfig

var state: State = State.HIDDEN

var _viewport: SubViewport
var _painter: PlayerGlyphView.AtlasPainter
var _multimesh: MultiMesh
var _instance: MultiMeshInstance3D
var _material: ShaderMaterial

var _identity: String = ""
var _layout: EntityLayout
var _slot_of: Dictionary = {}
var _grow_t: float = SETTLED
var _grow_end: float = 0.0
var _fold_t: float = -1.0
var _fold_end: float = 0.0
var _death_t: float = -1.0
var _death_life: float = 1.0
var _last_centre: Vector3 = Vector3.ZERO
var _has_last: bool = false
var _velocity: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	top_level = true
	if config == null:
		config = EntityGrowthConfig.new()
	if fx_config == null:
		fx_config = GlyphFxConfig.new()
	if player_config == null:
		player_config = PlayerConfig.new()
	_build_atlas()
	_build_instance()


## Number of body glyphs around the heart.
func glyph_count() -> int:
	return _layout.size() if _layout != null else 0


## True while the body is drawn (growing, settled or folding).
func is_shown() -> bool:
	return state != State.HIDDEN


## True while the grow moment is playing (including the delay before it starts).
func is_growing() -> bool:
	return state == State.GROWING


## True from the burst until the next run.
func is_burst() -> bool:
	return _death_t >= 0.0


## Seconds the grow moment takes from its start (delay included) until every glyph has landed.
func grow_duration() -> float:
	return config.grow_delay + _grow_end


## Heart scale while the glyphs land (1 outside the pulse).
func heart_scale() -> float:
	if state != State.GROWING or config.heart_pulse <= 0.0:
		return 1.0
	var x: float = (_grow_t - (_grow_end - config.grow_duration * 0.35)) / maxf(config.heart_pulse_time, 0.001)
	if x <= 0.0 or x >= 1.0:
		return 1.0
	return 1.0 + config.heart_pulse * sin(PI * x)


## Applies a form. animate = play the grow / fold, otherwise it just appears / vanishes.
func set_form(form: StringName, animate: bool) -> void:
	if form == EntityForm.GROWN:
		if animate and state != State.GROWN:
			_grow_t = -config.grow_delay
			_fold_t = -1.0
			state = State.GROWING
		else:
			_grow_t = SETTLED
			_fold_t = -1.0
			state = State.GROWN
	else:
		if animate and state != State.HIDDEN:
			_fold_t = 0.0
			state = State.FOLDING
		else:
			_fold_t = -1.0
			state = State.HIDDEN
	_apply_visibility()


## Rebuilds the body for an identity (the same identity always gives the same body).
func use_identity(identity: String) -> void:
	if identity == _identity and _layout != null:
		return
	_identity = identity
	_rebuild()


## The body bursts: every glyph flies out and fades over `life` seconds.
func burst(life: float) -> void:
	_death_t = 0.0
	_death_life = life
	_material.set_shader_parameter(&"death_life", life)


## A new run: the body is whole again.
func reset_run() -> void:
	_death_t = -1.0
	_material.set_shader_parameter(&"death_t", -1.0)
	_has_last = false
	_velocity = Vector2.ZERO


## Per frame, from PlayerGlyphView: advances the clocks and sets the uniforms.
func present(delta: float, centre: Vector3, level: float, tint: Color, visible_now: bool) -> void:
	if state == State.HIDDEN or _layout == null:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	_step_trail(delta, centre, camera)
	_step_clocks(delta)
	_material.set_shader_parameter(&"centre", centre)
	_material.set_shader_parameter(&"level", level)
	_material.set_shader_parameter(&"erosion_tint", Vector3(tint.r, tint.g, tint.b))
	_material.set_shader_parameter(&"opacity", 1.0 if visible_now else 0.0)
	_material.set_shader_parameter(&"trail", _velocity * config.trail_lag)


func _step_clocks(delta: float) -> void:
	if state == State.GROWING:
		_grow_t += delta
		_material.set_shader_parameter(&"grow_t", _grow_t)
		if _grow_t >= _grow_end:
			state = State.GROWN
			_grow_t = SETTLED
			_material.set_shader_parameter(&"grow_t", SETTLED)
	elif state == State.FOLDING:
		_fold_t += delta
		_material.set_shader_parameter(&"fold_t", _fold_t)
		if _fold_t >= _fold_end:
			state = State.HIDDEN
			_apply_visibility()
	if _death_t >= 0.0:
		_death_t += delta
		_material.set_shader_parameter(&"death_t", _death_t)


## Smoothed velocity of the heart on the camera plane (x right, y up).
func _step_trail(delta: float, centre: Vector3, camera: Camera3D) -> void:
	if not _has_last or camera == null or delta <= 0.0:
		_last_centre = centre
		_has_last = true
		return
	var b: Basis = camera.global_transform.basis
	var moved: Vector3 = (centre - _last_centre) / delta
	_last_centre = centre
	var v := Vector2(moved.dot(b.x), moved.dot(b.y))
	if v.length() > MAX_TRAIL_SPEED:
		v = v.normalized() * MAX_TRAIL_SPEED
	_velocity = _velocity.lerp(v, 1.0 - exp(-config.trail_follow * delta))


func _apply_visibility() -> void:
	if _instance == null:
		return
	_instance.visible = state != State.HIDDEN
	if _material != null:
		_material.set_shader_parameter(&"grow_t", _grow_t)
		_material.set_shader_parameter(&"fold_t", _fold_t)
		_material.set_shader_parameter(&"fold_dur", config.fold_duration)
		_material.set_shader_parameter(&"death_t", _death_t)


func _build_atlas() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "EntityAtlas"
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_painter = PlayerGlyphView.AtlasPainter.new()
	_painter.name = "Painter"
	var font := SystemFont.new()
	font.font_names = player_config.font_names
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.font_weight = config.font_weight
	_painter.font = font
	_painter.tile = fx_config.atlas_tile_px
	_painter.font_px = int(fx_config.atlas_tile_px * fx_config.font_fill)
	_viewport.add_child(_painter)


func _build_instance() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(QUAD_EXTENT, QUAD_EXTENT)
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.use_custom_data = true
	_multimesh.mesh = quad
	_material = ShaderMaterial.new()
	_material.shader = load(ENTITY_SHADER) as Shader
	_material.render_priority = 2
	_material.set_shader_parameter(&"glyph_atlas", _viewport.get_texture())
	_material.set_shader_parameter(&"glyph_fill", config.glyph_fill)
	_material.set_shader_parameter(&"outline_color", config.outline_color)
	_material.set_shader_parameter(&"outline_width", config.outline_width)
	_material.set_shader_parameter(&"blend_max", config.erosion_blend_max)
	_material.set_shader_parameter(&"tint_strength", config.erosion_tint_strength)
	_material.set_shader_parameter(&"fade_min_alpha", config.erosion_min_alpha)
	_material.set_shader_parameter(&"shed_share", config.shed_share)
	_material.set_shader_parameter(&"shed_period", config.shed_period)
	_material.set_shader_parameter(&"shed_distance", config.shed_distance)
	_material.set_shader_parameter(&"shed_min_alpha", config.shed_min_alpha)
	_material.set_shader_parameter(&"sub_period", config.sub_period)
	_material.set_shader_parameter(&"bob_amount", config.bob_amount)
	_material.set_shader_parameter(&"bob_speed", config.bob_speed)
	_material.set_shader_parameter(&"pop", config.pop)
	_material.set_shader_parameter(&"flash", config.flash)
	_material.set_shader_parameter(&"overshoot", config.overshoot)
	_material.set_shader_parameter(&"death_dist", config.death_spread)
	_material.set_shader_parameter(&"gather_color", Vector3(config.gather_color.r, config.gather_color.g, config.gather_color.b))
	_material.set_shader_parameter(&"fold_dur", config.fold_duration)
	_instance = MultiMeshInstance3D.new()
	_instance.name = "Body"
	_instance.multimesh = _multimesh
	_instance.material_override = _material
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_instance.custom_aabb = AABB(Vector3.ONE * -CULL_HALF_EXTENT, Vector3.ONE * CULL_HALF_EXTENT * 2.0)
	_instance.visible = false
	add_child(_instance)
	if _identity != "":
		_rebuild()


## Resolves the layout, rasterises its glyphs into the atlas and writes the instance buffer once.
func _rebuild() -> void:
	if _multimesh == null:
		return
	var formation: EntityFormation = config.formation_for(_identity)
	_layout = formation.resolve(_identity, config.body_glyphs) if formation != null else EntityLayout.new()
	var n: int = _layout.size()
	_multimesh.instance_count = n
	if n == 0:
		return
	_build_slots()
	_rng.seed = hash("%s/entity" % _identity)
	var half: float = config.glyph_size / config.glyph_fill * 0.5
	var grow_end: float = 0.0
	for i in n:
		var ring: int = _layout.rings[i]
		var delay: float = float(ring - 1) * config.grow_stagger + _rng.randf() * config.grow_jitter
		var duration: float = config.grow_duration * (0.85 + _rng.randf() * 0.3)
		grow_end = maxf(grow_end, delay + duration)
		var angle: float = _rng.randf() * TAU
		var radius: float = config.gather_radius * (0.7 + _rng.randf() * 0.4)
		var start := Vector2(cos(angle), sin(angle)) * radius
		# Whole turns only, so every glyph lands upright.
		var spin: float = maxf(roundf(config.spin_turns * (0.4 + _rng.randf() * 0.6)), 1.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var arc: float = config.arc_height * (0.6 + _rng.randf() * 0.4)
		var from_glyph: String = config.gather_glyphs[_rng.randi() % config.gather_glyphs.length()]
		var seed_value: float = _rng.randf()
		var offset: Vector2 = _layout.offsets[i]
		var basis := Basis(Vector3(offset.x, offset.y, half), Vector3(start.x, start.y, delay), Vector3(duration, spin, arc))
		var origin := Vector3(float(_slot_of[from_glyph]), float(_slot_of[_layout.glyphs[i]]), seed_value)
		_multimesh.set_instance_transform(i, Transform3D(basis, origin))
		var base_color: Color = config.structural_color if _layout.structural[i] == 1 else config.filler_color
		var shade: float = 1.0 - config.body_variation * _rng.randf()
		_multimesh.set_instance_color(i, Color(base_color.r * shade, base_color.g * shade, base_color.b * shade, 1.0))
		_multimesh.set_instance_custom_data(i, Color(config.start_size_ratio, 0.0, 0.0, 0.0))
	_grow_end = grow_end
	_fold_end = config.fold_duration + grow_end * 0.4


## Atlas slots: [body glyphs..., substitute glyphs..., gather glyphs...]; tells the shader the grid and the substitute range.
func _build_slots() -> void:
	var glyphs := PackedStringArray()
	_slot_of.clear()
	for g in _layout.glyphs:
		_add_slot(glyphs, g)
	var sub_first: int = glyphs.size()
	for ch in fx_config.scramble_glyphs:
		_add_slot(glyphs, ch)
	var sub_count: int = glyphs.size() - sub_first
	for ch in config.gather_glyphs:
		_add_slot(glyphs, ch)
	var cols: int = ceili(sqrt(float(glyphs.size())))
	var rows: int = ceili(float(glyphs.size()) / float(cols))
	_painter.glyphs = glyphs
	_painter.cols = cols
	_viewport.size = Vector2i(cols, rows) * fx_config.atlas_tile_px
	_material.set_shader_parameter(&"atlas_grid", Vector2(cols, rows))
	_material.set_shader_parameter(&"sub_first", float(sub_first))
	_material.set_shader_parameter(&"sub_count", float(maxi(sub_count, 1)))
	_painter.queue_redraw()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _add_slot(glyphs: PackedStringArray, glyph: String) -> void:
	if _slot_of.has(glyph):
		return
	_slot_of[glyph] = glyphs.size()
	glyphs.append(glyph)
