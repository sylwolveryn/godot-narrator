class_name PlayerGlyphView
extends Node3D
## The player's identity glyph standing in the isometric world (task-033, replaces the overlay glyph).
## One MultiMesh of camera-facing quads (shaders/glyph_actor.gdshader, ONE draw call): instance 0 is the
## player's glyph with its warm halo, the other instances are glyph fragments (shed while eroding, flung out at
## death). The glyph pictures come from a small runtime atlas: a SubViewport rasterises the identity glyph and the
## substitute glyphs with the player's fonts once (and again when the identity changes), so any glyph the font
## can draw works. Erosion distorts the glyph progressively (continuous blend into a substitute glyph, slow warp,
## violet ghost, tint, fade); death breaks it into fragments that fly outward and fade. Erosion and death arrive
## by SignalBus signals; this node only presents, it never writes data. No per-frame allocations.

const ACTOR_SHADER: String = "res://shaders/glyph_actor.gdshader"
const PLAYER_INSTANCE: int = 0
## Atlas slots are packed two per float in the shader (slot B + SLOT_PACK * slot C).
const SLOT_PACK: int = 64
## Atlas slot of the identity glyph; substitute glyphs follow.
const IDENTITY_SLOT: int = 0
## Fragment arrays use this age for a free fragment.
const FREE: float = -1.0
## Largest edge of the quad mesh (the shader scales it by the instance scale).
const QUAD_EXTENT: float = 2.0

@export var player: Player
@export var player_config: PlayerConfig
@export var fx_config: GlyphFxConfig
## The player light colour (halo colour) comes from here.
@export var world_config: GlyphWorldConfig
## Cell size for fragment distances.
@export var world: WorldConfig
## The grown multi-glyph entity (task-017): its body is a second MultiMesh (EntityGlyphView), the heart stays instance 0.
@export var entity_config: EntityGrowthConfig

var _rng := RandomNumberGenerator.new()
var _viewport: SubViewport
var _painter: AtlasPainter
var _multimesh: MultiMesh
var _instance: MultiMeshInstance3D
var _material: ShaderMaterial

var _identity: String = ""
var _pool: PackedStringArray = PackedStringArray()
var _half_size: float = 1.0

var _erosion: float = 0.0
var _level_shown: float = 0.0
var _tint: Color = Color.WHITE
var _death_tint: Color = Color.WHITE
var _flashing: bool = false
var _dying: bool = false
var _death_clock: float = 0.0
var _player_visible: bool = false

var _slot_b: int = 1
var _slot_c: int = 1
var _morph: float = 0.0
var _morphing: bool = false
var _retarget_in: float = 0.0
var _shed_in: float = 0.0

var _entity: EntityGlyphView
var _form: StringName = EntityForm.SINGLE

var _frag_age: PackedFloat32Array = PackedFloat32Array()
var _frag_life: PackedFloat32Array = PackedFloat32Array()
var _frag_dist: PackedFloat32Array = PackedFloat32Array()
var _frag_scale: PackedFloat32Array = PackedFloat32Array()
var _frag_slot: PackedInt32Array = PackedInt32Array()
var _frag_origin: PackedVector3Array = PackedVector3Array()
var _frag_dir: PackedVector3Array = PackedVector3Array()
var _frag_color: PackedColorArray = PackedColorArray()
var _clear_color := Color(1.0, 1.0, 1.0, 0.0)


## Draws the atlas tiles: one glyph per tile, centred, white on transparent.
class AtlasPainter extends Node2D:
	var font: Font
	var glyphs: PackedStringArray = PackedStringArray()
	var cols: int = 1
	var tile: int = 128
	var font_px: int = 92
	## A glyph wider than this fraction of the tile is shrunk to fit.
	var max_width: float = 0.92

	func _draw() -> void:
		for i in glyphs.size():
			var text: String = glyphs[i]
			if text == "":
				continue
			var px: int = font_px
			var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			if width > tile * max_width:
				px = maxi(int(px * tile * max_width / width), 1)
				width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			var cx: float = float(i % cols) * tile + tile * 0.5
			var cy: float = floorf(float(i) / float(cols)) * tile + tile * 0.5
			var baseline: float = cy + (font.get_ascent(px) - font.get_descent(px)) * 0.5
			font.draw_string(get_canvas_item(), Vector2(cx - width * 0.5, baseline), text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)


func _ready() -> void:
	if player_config == null:
		player_config = PlayerConfig.new()
	if fx_config == null:
		fx_config = GlyphFxConfig.new()
	if world_config == null:
		world_config = GlyphWorldConfig.new()
	if world == null:
		world = WorldConfig.new()
	_rng.randomize()
	for ch in fx_config.scramble_glyphs:
		_pool.append(ch)
	_half_size = fx_config.glyph_size / fx_config.glyph_fill * 0.5
	_build_atlas()
	_build_multimesh()
	_build_entity()
	_slot_b = _random_slot()
	_slot_c = _slot_b
	SignalBus.erosion_changed.connect(_on_erosion_changed)
	SignalBus.hazard_lethal.connect(_on_hazard_lethal)
	SignalBus.run_ended.connect(_on_run_ended)
	SignalBus.run_started.connect(_on_run_started)
	SignalBus.entity_form_changed.connect(set_form)
	if player != null:
		player.identity_changed.connect(_on_identity_changed)
		if player.identity_glyph != "":
			_on_identity_changed(player.identity_glyph)


func _process(delta: float) -> void:
	if player == null:
		return
	_step_level(delta)
	var level: float = _remapped_level()
	if not _dying:
		_step_corruption(level, delta)
	_step_death(delta)
	_write_player(level)
	_write_fragments(delta)
	_entity.present(delta, _glyph_centre(), level, _tint, _identity != "")


## Shows the single glyph or the grown entity. animate = play the grow / fold morph, otherwise it just appears.
## Connected to SignalBus.entity_form_changed; the in-world menu (task-018) switches form through EntityProgression.
func set_form(form: StringName, animate: bool = true) -> void:
	if not EntityForm.is_valid(form):
		return
	_form = form
	_entity.set_form(form, animate)


## The form currently shown (EntityForm.SINGLE / GROWN).
func form() -> StringName:
	return _form


## The entity body view (glyph count, grow state) for presentation checks and tools.
func entity_body() -> EntityGlyphView:
	return _entity


## The currently shown erosion as the shader's 0..1 level (0 below scramble_start).
func shown_level() -> float:
	return _remapped_level()


## Number of live fragments (shed or death).
func fragment_count() -> int:
	var n: int = 0
	for age in _frag_age:
		if age != FREE:
			n += 1
	return n


## True while the player's own glyph is drawn (hidden between the burst and the next run).
func is_glyph_visible() -> bool:
	return _player_visible


## The identity glyph currently shown.
func identity_text() -> String:
	return _identity


func _build_entity() -> void:
	_entity = EntityGlyphView.new()
	_entity.name = "EntityBody"
	_entity.config = entity_config if entity_config != null else EntityGrowthConfig.new()
	_entity.fx_config = fx_config
	_entity.player_config = player_config
	add_child(_entity)


func _build_atlas() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "GlyphAtlas"
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_painter = AtlasPainter.new()
	_painter.name = "Painter"
	var font := SystemFont.new()
	font.font_names = player_config.font_names
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_painter.font = font
	_painter.tile = fx_config.atlas_tile_px
	_painter.font_px = int(fx_config.atlas_tile_px * fx_config.font_fill)
	_viewport.add_child(_painter)


func _build_multimesh() -> void:
	var shed_capacity: int = ceili(fx_config.shed_lifetime / maxf(fx_config.erosion_shed_interval, 0.05)) + 1
	var capacity: int = 1 + fx_config.death_fragments + shed_capacity
	var quad := QuadMesh.new()
	quad.size = Vector2(QUAD_EXTENT, QUAD_EXTENT)
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.use_custom_data = true
	_multimesh.mesh = quad
	_multimesh.instance_count = capacity
	_frag_age.resize(capacity)
	_frag_life.resize(capacity)
	_frag_dist.resize(capacity)
	_frag_scale.resize(capacity)
	_frag_slot.resize(capacity)
	_frag_origin.resize(capacity)
	_frag_dir.resize(capacity)
	_frag_color.resize(capacity)
	_frag_age.fill(FREE)
	for i in capacity:
		_multimesh.set_instance_color(i, _clear_color)
	_material = ShaderMaterial.new()
	_material.shader = load(ACTOR_SHADER) as Shader
	_material.render_priority = 1
	_material.set_shader_parameter(&"glyph_atlas", _viewport.get_texture())
	_material.set_shader_parameter(&"lift", fx_config.lift)
	_material.set_shader_parameter(&"glyph_fill", fx_config.glyph_fill)
	_material.set_shader_parameter(&"blend_max", fx_config.glyph_blend_max)
	_material.set_shader_parameter(&"warp_max", fx_config.warp_max)
	_material.set_shader_parameter(&"warp_period", fx_config.warp_period)
	_material.set_shader_parameter(&"ghost_offset", fx_config.ghost_offset)
	_material.set_shader_parameter(&"outline_color", fx_config.outline_color)
	_material.set_shader_parameter(&"outline_width", fx_config.outline_width)
	var light: Color = world_config.player_light_color
	_material.set_shader_parameter(&"halo_color", Vector3(light.r, light.g, light.b))
	_material.set_shader_parameter(&"halo_intensity", fx_config.halo_intensity)
	_material.set_shader_parameter(&"halo_pool", fx_config.halo_pool)
	_material.set_shader_parameter(&"halo_ref_size", _half_size)
	_material.set_shader_parameter(&"halo_breath_amount", fx_config.halo_breath_amount)
	_material.set_shader_parameter(&"halo_breath_period", fx_config.halo_breath_period)
	_instance = MultiMeshInstance3D.new()
	_instance.name = "Actors"
	_instance.multimesh = _multimesh
	_instance.material_override = _material
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_instance.extra_cull_margin = fx_config.lift + fx_config.death_spread_cells * _cell_size() + _half_size
	add_child(_instance)


## Rasterises [identity, substitute glyphs...] into the atlas and tells the shader the grid.
func _rebuild_atlas() -> void:
	var glyphs := PackedStringArray()
	glyphs.append(_identity)
	glyphs.append_array(_pool)
	var cols: int = ceili(sqrt(float(glyphs.size())))
	var rows: int = ceili(float(glyphs.size()) / float(cols))
	_painter.glyphs = glyphs
	_painter.cols = cols
	_viewport.size = Vector2i(cols, rows) * fx_config.atlas_tile_px
	_material.set_shader_parameter(&"atlas_grid", Vector2(cols, rows))
	_painter.queue_redraw()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Moves the shown level towards the target (erosion, or full while the death flash runs): fast up, quick down.
func _step_level(delta: float) -> void:
	var target: float = 1.0 if _flashing else _erosion
	var time: float = fx_config.flash_rise if target > _level_shown else fx_config.flash_decay
	_level_shown = move_toward(_level_shown, target, delta / maxf(time, 0.001))


func _remapped_level() -> float:
	var span: float = maxf(1.0 - fx_config.scramble_start, 0.001)
	return clampf((_level_shown - fx_config.scramble_start) / span, 0.0, 1.0)


## Eroding: the substitute glyph changes at most every erosion_retarget_min seconds, always through a crossfade;
## above the shed threshold a fragment drifts off every erosion_shed_interval seconds.
func _step_corruption(level: float, delta: float) -> void:
	if _morphing:
		_morph += delta / maxf(fx_config.corrupt_morph_time, 0.001)
		if _morph >= 1.0:
			_slot_b = _slot_c
			_morph = 0.0
			_morphing = false
	if level > 0.0:
		_retarget_in -= delta
		if _retarget_in <= 0.0 and not _morphing:
			_retarget_in = fx_config.erosion_retarget_min
			var next: int = _random_slot()
			if next != _slot_b:
				_slot_c = next
				_morphing = true
	if _erosion >= fx_config.erosion_shed_threshold and _player_visible:
		_shed_in -= delta
		if _shed_in <= 0.0:
			_shed_in = fx_config.erosion_shed_interval
			_shed_fragment()
	else:
		_shed_in = 0.0


func _step_death(delta: float) -> void:
	if not _dying:
		return
	_death_clock += delta
	if _flashing and _death_clock >= fx_config.shatter_flash:
		_flashing = false
		_burst()


func _write_player(level: float) -> void:
	if not _player_visible or player == null:
		_multimesh.set_instance_color(PLAYER_INSTANCE, _clear_color)
		return
	var pos: Vector3 = player.global_position + Vector3.UP * player_config.glyph_height
	_multimesh.set_instance_transform(PLAYER_INSTANCE, Transform3D(Basis.from_scale(Vector3.ONE * _half_size * _entity.heart_scale()), pos))
	var col: Color = player_config.glyph_color.lerp(_tint, level * fx_config.tint_strength)
	col.a = lerpf(1.0, fx_config.fade_min_alpha, level)
	_multimesh.set_instance_color(PLAYER_INSTANCE, col)
	_multimesh.set_instance_custom_data(PLAYER_INSTANCE,
			Color(float(IDENTITY_SLOT), float(_slot_b + SLOT_PACK * _slot_c), level, _morph if _morphing else 0.0))


func _write_fragments(delta: float) -> void:
	for i in range(1, _frag_age.size()):
		var age: float = _frag_age[i]
		if age == FREE:
			continue
		age += delta
		var life: float = _frag_life[i]
		if age >= life:
			_frag_age[i] = FREE
			_multimesh.set_instance_color(i, _clear_color)
			continue
		_frag_age[i] = age
		var t: float = age / life
		var eased: float = 1.0 - pow(1.0 - t, 3.0)
		var pos: Vector3 = _frag_origin[i] + _frag_dir[i] * (_frag_dist[i] * eased)
		_multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * _frag_scale[i]), pos))
		var col: Color = _frag_color[i]
		col.a = 1.0 - t
		_multimesh.set_instance_color(i, col)
		_multimesh.set_instance_custom_data(i, Color(float(_frag_slot[i]), 0.0, 0.0, 0.0))


## A fragment of the eroding glyph drifts off in a random screen direction.
func _shed_fragment() -> void:
	var dir: Vector3 = _screen_direction(_rng.randf() * TAU)
	_spawn_fragment(_glyph_centre(), dir, _random_slot(), fx_config.shed_lifetime,
			fx_config.shed_distance_cells * _cell_size(), fx_config.shard_size_ratio * _half_size,
			player_config.glyph_color.lerp(_tint, fx_config.tint_strength))


## The glyph bursts: its fragments fly outward and fade over the rest of death_duration.
func _burst() -> void:
	_player_visible = false
	var life: float = maxf(fx_config.death_duration - fx_config.shatter_flash, 0.01)
	var n: int = maxi(fx_config.death_fragments, 1)
	var centre: Vector3 = _glyph_centre()
	var col: Color = player_config.glyph_color.lerp(_death_tint, fx_config.tint_strength)
	_entity.burst(life)
	for i in n:
		var angle: float = TAU * (float(i) + _rng.randf()) / float(n)
		var dist: float = fx_config.death_spread_cells * _cell_size() * (1.0 - _rng.randf() * fx_config.shard_distance_spread)
		var slot: int = IDENTITY_SLOT if i % 3 == 0 else _random_slot()
		_spawn_fragment(centre, _screen_direction(angle), slot, life, dist, fx_config.shard_size_ratio * _half_size, col)


func _spawn_fragment(origin: Vector3, dir: Vector3, slot: int, life: float, dist: float, scale_value: float, col: Color) -> void:
	for i in range(1, _frag_age.size()):
		if _frag_age[i] != FREE:
			continue
		_frag_age[i] = 0.0
		_frag_life[i] = life
		_frag_dist[i] = dist
		_frag_scale[i] = scale_value
		_frag_slot[i] = slot
		_frag_origin[i] = origin
		_frag_dir[i] = dir
		_frag_color[i] = col
		return


## A unit direction on the screen plane (right / up of the camera) at an angle.
func _screen_direction(angle: float) -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(cos(angle), sin(angle), 0.0)
	var b: Basis = camera.global_transform.basis
	return (b.x * cos(angle) + b.y * sin(angle)).normalized()


func _glyph_centre() -> Vector3:
	return player.global_position + Vector3.UP * player_config.glyph_height


func _cell_size() -> float:
	return world.cell_size


## A random substitute glyph slot (slot 0 is the identity); falls back to the identity when there are none.
func _random_slot() -> int:
	if _pool.is_empty():
		return IDENTITY_SLOT
	return 1 + _rng.randi() % _pool.size()


func _on_identity_changed(glyph: String) -> void:
	_player_visible = glyph != "" and not _dying
	if glyph == _identity:
		return
	_identity = glyph
	_rebuild_atlas()
	_entity.use_identity(glyph)


func _on_erosion_changed(amount: float, tint: Color) -> void:
	_erosion = amount
	if amount > 0.0:
		_set_tint(tint)


func _on_hazard_lethal(_cause: StringName, tint: Color) -> void:
	_death_tint = tint


func _on_run_started(_run_index: int) -> void:
	_dying = false
	_flashing = false
	_death_clock = 0.0
	_erosion = 0.0
	_level_shown = 0.0
	_morph = 0.0
	_morphing = false
	_retarget_in = 0.0
	_shed_in = 0.0
	_death_tint = Color.WHITE
	_set_tint(Color.WHITE)
	_frag_age.fill(FREE)
	for i in range(1, _frag_age.size()):
		_multimesh.set_instance_color(i, _clear_color)
	_player_visible = _identity != ""
	_entity.reset_run()


func _on_run_ended(_cause: StringName) -> void:
	if _dying or not _player_visible:
		return
	_dying = true
	_flashing = true
	_death_clock = 0.0
	_set_tint(_death_tint)


func _set_tint(tint: Color) -> void:
	_tint = tint
	_material.set_shader_parameter(&"ghost_color", Vector3(tint.r, tint.g, tint.b))
