class_name GlyphOverlay
extends CanvasLayer
## Overlay layer (>= 10, above the ASCII post-process) that draws the player's identity glyph at the
## camera projection of the player's world position (decision-001). The glyph is an SDF quad
## (GlyphQuad, shared atlas), so every change is a shape blend, never a character swap:
##  - Erosion: the identity morphs toward a seeded corrupt glyph with t = erosion (plus a slow domain
##    warp). The target changes at most every `erosion_retarget_min` seconds and only through a morph.
##    The colour and glow shift to the erosion tint; above the shed threshold fragments drift off.
##  - Death: the glyph splits into angular slices that fly outward and morph identity -> abstract ->
##    empty, tinted with the killer's colour. Nothing strobes.
## Erosion arrives by SignalBus signals; this node never writes data.

@export var camera_rig: CameraRig
@export var player: Player
@export var player_config: PlayerConfig
@export var fx_config: GlyphFxConfig
@export var display_config: DisplayConfig
@export var world_config: WorldConfig
## Owner of the shared SDF atlas.
@export var ascii: AsciiPostProcess

## Quads kept for shed fragments (the shed interval is shorter than the shed duration).
const SHED_POOL := 3

## One flying fragment (a death slice or a shed glyph).
class Fragment extends RefCounted:
	var quad: GlyphQuad
	var elapsed: float = 0.0
	var duration: float = 1.0
	var origin: Vector2 = Vector2.ZERO
	var direction: Vector2 = Vector2.RIGHT
	var reach: float = 0.0
	var start_scale: float = 1.0
	var end_scale: float = 1.0
	var active: bool = false

var _atlas: GlyphAtlas
var _quad: GlyphQuad
var _death_pool: Array[Fragment] = []
var _shed_pool: Array[Fragment] = []
var _scale: float = 1.0
var _rng := RandomNumberGenerator.new()
var _identity: String = ""
var _identity_index: int = 0
var _corrupt: PackedInt32Array = PackedInt32Array()
var _abstract: PackedInt32Array = PackedInt32Array()
var _erosion: float = 0.0
var _death_tint: Color = Color.WHITE
var _dying: bool = false
var _warp_seed: float = 0.0
## Erosion target: current glyph, the glyph it is retargeting to and how far that morph is (0..1).
var _target: int = 0
var _next_target: int = 0
var _retarget_progress: float = 0.0
var _retargeting: bool = false
var _since_retarget: float = 0.0
var _shed_clock: float = 0.0


func _ready() -> void:
	if player_config == null:
		player_config = PlayerConfig.new()
	if fx_config == null:
		fx_config = GlyphFxConfig.new()
	if display_config == null:
		display_config = DisplayConfig.new()
	_rng.randomize()
	get_viewport().size_changed.connect(_apply_scale)
	SignalBus.erosion_changed.connect(_on_erosion_changed)
	SignalBus.hazard_lethal.connect(_on_hazard_lethal)
	SignalBus.run_ended.connect(_on_run_ended)
	SignalBus.run_started.connect(_on_run_started)
	if player != null:
		player.identity_changed.connect(_on_identity_changed)
		if player.identity_glyph != "":
			_identity = player.identity_glyph
	if ascii != null:
		if ascii.atlas.ready:
			_on_atlas_ready()
		else:
			ascii.ready_to_draw.connect(_on_atlas_ready, CONNECT_ONE_SHOT)


## True once the atlas exists and the glyph quads are built.
func is_ready() -> bool:
	return _quad != null


## Builds the quads from the baked atlas.
func _on_atlas_ready() -> void:
	_atlas = ascii.atlas
	_corrupt = _indices(fx_config.corrupt_glyphs)
	_abstract = _indices(fx_config.fragment_glyphs)
	_quad = _make_quad()
	_quad.name = "PlayerGlyph"
	add_child(_quad)
	for i in fx_config.death_fragments:
		_death_pool.append(_make_fragment())
	for i in SHED_POOL:
		_shed_pool.append(_make_fragment())
	_apply_scale()
	_set_identity(_identity)


func _make_quad() -> GlyphQuad:
	var quad: GlyphQuad = GlyphQuad.new().setup(_atlas)
	quad.set_pad(player_config.glow_pad)
	quad.set_bump(fx_config.morph_scale_dip, fx_config.morph_glow_boost)
	quad.set_colors(player_config.glyph_color, player_config.glow_color, player_config.glow_strength, player_config.glow_radius)
	quad.visible = false
	return quad


func _make_fragment() -> Fragment:
	var frag := Fragment.new()
	frag.quad = _make_quad()
	add_child(frag.quad)
	return frag


func _indices(chars: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in chars.length():
		var ch: String = chars[i]
		if _atlas.has_char(ch):
			out.append(_atlas.index_of(ch))
	return out


func _process(delta: float) -> void:
	if _quad == null or camera_rig == null or player == null:
		return
	var screen_pos: Vector2 = camera_rig.camera.unproject_position(player.global_position)
	if _quad.visible:
		_update_identity(delta, screen_pos)
	_update_fragments(delta)


## Re-derives every pixel size from the window height.
func _apply_scale() -> void:
	_scale = display_config.scale_for(get_viewport())
	if _quad == null:
		return
	var font_px: float = player_config.font_size * _scale
	_quad.fit_to_font(font_px)
	for frag in _death_pool + _shed_pool:
		frag.quad.fit_to_font(font_px)


func _update_identity(delta: float, screen_pos: Vector2) -> void:
	_update_retarget(delta)
	var morph: float = _eased(_erosion)
	var retarget: float = _eased(_retarget_progress) if _retargeting else 0.0
	_quad.set_shape(_identity_index, _target, morph, _next_target, retarget)
	var core: Color = player_config.glyph_color.lerp(fx_config.erosion_tint, _erosion)
	var glow: Color = player_config.glow_color.lerp(fx_config.erosion_tint, _erosion)
	_quad.set_colors(core, glow, player_config.glow_strength, player_config.glow_radius)
	_quad.set_warp(fx_config.erosion_warp_amp * _erosion, fx_config.erosion_warp_hz, _warp_seed)
	_quad.centre_on(screen_pos)
	if _erosion >= fx_config.erosion_shed_threshold:
		_shed_clock += delta
		if _shed_clock >= fx_config.erosion_shed_interval:
			_shed_clock = 0.0
			_shed(screen_pos)
	else:
		_shed_clock = 0.0


## The corrupt target may change at most every `erosion_retarget_min` seconds, and only by morphing.
func _update_retarget(delta: float) -> void:
	if _erosion <= 0.0:
		_since_retarget = 0.0
		return
	if _retargeting:
		_retarget_progress += delta / maxf(fx_config.erosion_retarget_morph, 0.001)
		if _retarget_progress >= 1.0:
			_target = _next_target
			_retargeting = false
			_retarget_progress = 0.0
			_since_retarget = 0.0
		return
	_since_retarget += delta
	if _since_retarget >= fx_config.erosion_retarget_min and _corrupt.size() > 1:
		_next_target = _pick_corrupt(_target)
		_retargeting = true
		_retarget_progress = 0.0


func _pick_corrupt(exclude: int) -> int:
	if _corrupt.is_empty():
		return _identity_index
	var pick: int = _corrupt[_rng.randi() % _corrupt.size()]
	if pick == exclude:
		pick = _corrupt[(_corrupt.find(pick) + 1) % _corrupt.size()]
	return pick


func _eased(value: float) -> float:
	return Tween.interpolate_value(0.0, 1.0, clampf(value, 0.0, 1.0), 1.0, fx_config.default_trans, fx_config.default_ease)


func _set_identity(glyph: String) -> void:
	_identity = glyph
	if _quad == null:
		return
	var shown: String = glyph
	if not _atlas.has_char(shown):
		shown = _fallback_glyph()
	_identity_index = _atlas.index_of(shown)
	_rng.seed = hash(glyph)
	_warp_seed = _rng.randf() * TAU
	_target = _pick_corrupt(-1)
	_next_target = _target
	_retargeting = false
	_retarget_progress = 0.0
	_quad.visible = glyph != "" and not _dying


func _fallback_glyph() -> String:
	if player_config.identity_pool != null:
		return player_config.identity_pool.fallback_glyph
	return "@"


func _on_identity_changed(glyph: String) -> void:
	_set_identity(glyph)


func _on_erosion_changed(amount: float, _tint: Color) -> void:
	_erosion = clampf(amount, 0.0, 1.0)


func _on_hazard_lethal(_cause: StringName, tint: Color) -> void:
	_death_tint = tint


func _on_run_started(_run_index: int) -> void:
	_dying = false
	_erosion = 0.0
	_death_tint = Color.WHITE
	_retargeting = false
	_retarget_progress = 0.0
	_since_retarget = 0.0
	for frag in _death_pool + _shed_pool:
		_stop(frag)
	if _quad != null:
		_quad.visible = _identity != ""


## Size of one map cell in screen pixels at a world position (fragment travel distance).
func _map_cell_px(at: Vector3) -> float:
	var cell: float = world_config.cell_size if world_config != null else 1.0
	var a: Vector2 = camera_rig.camera.unproject_position(at)
	var b: Vector2 = camera_rig.camera.unproject_position(at + Vector3(cell, 0.0, 0.0))
	return a.distance_to(b)


func _on_run_ended(_cause: StringName) -> void:
	if _dying or _quad == null or not _quad.visible or camera_rig == null:
		return
	_dying = true
	var centre: Vector2 = camera_rig.camera.unproject_position(player.global_position)
	var shape_a: int = _target if _erosion > 0.5 else _identity_index
	var count: int = _death_pool.size()
	var half: float = PI / float(maxi(count, 1))
	var reach: float = fx_config.death_spread_cells * _map_cell_px(player.global_position)
	_quad.visible = false
	for i in count:
		var frag: Fragment = _death_pool[i]
		var mid: float = TAU * float(i) / float(count)
		frag.origin = centre
		frag.direction = Vector2.from_angle(mid)
		frag.reach = reach
		frag.duration = fx_config.death_duration
		frag.start_scale = 1.0
		frag.end_scale = fx_config.fragment_size_ratio
		var abstract_glyph: int = _abstract[i % _abstract.size()] if not _abstract.is_empty() else 0
		frag.quad.set_shape(shape_a, abstract_glyph, 0.0)
		frag.quad.set_colors(_death_tint, _death_tint, player_config.glow_strength, player_config.glow_radius)
		frag.quad.set_slice(mid, half + fx_config.slice_overlap)
		frag.quad.set_warp(0.0, fx_config.erosion_warp_hz, 0.0)
		_start(frag)


func _shed(centre: Vector2) -> void:
	var frag: Fragment = null
	for f in _shed_pool:
		if not f.active:
			frag = f
			break
	if frag == null:
		return
	var angle: float = _rng.randf() * TAU
	frag.origin = centre
	frag.direction = Vector2.from_angle(angle)
	frag.reach = fx_config.erosion_shed_drift * player_config.font_size * _scale
	frag.duration = fx_config.erosion_shed_duration
	frag.start_scale = fx_config.fragment_size_ratio
	frag.end_scale = fx_config.fragment_size_ratio * 0.6
	var abstract_glyph: int = _abstract[_rng.randi() % _abstract.size()] if not _abstract.is_empty() else 0
	var core: Color = player_config.glyph_color.lerp(fx_config.erosion_tint, _erosion)
	frag.quad.set_shape(_target, abstract_glyph, 0.0)
	frag.quad.set_colors(core, fx_config.erosion_tint, player_config.glow_strength, player_config.glow_radius)
	frag.quad.clear_slice()
	frag.quad.set_warp(0.0, fx_config.erosion_warp_hz, 0.0)
	_start(frag)


func _start(frag: Fragment) -> void:
	frag.elapsed = 0.0
	frag.active = true
	frag.quad.visible = true
	_place(frag, 0.0)


func _stop(frag: Fragment) -> void:
	frag.active = false
	frag.quad.visible = false


func _update_fragments(delta: float) -> void:
	for frag in _death_pool + _shed_pool:
		if not frag.active:
			continue
		frag.elapsed += delta
		var t: float = clampf(frag.elapsed / maxf(frag.duration, 0.001), 0.0, 1.0)
		_place(frag, t)
		if t >= 1.0:
			_stop(frag)


## Position, scale, shape blend and opacity of a fragment at progress t (0..1).
func _place(frag: Fragment, t: float) -> void:
	var travel: float = Tween.interpolate_value(0.0, 1.0, t, 1.0, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	frag.quad.centre_on(frag.origin + frag.direction * frag.reach * travel)
	frag.quad.scale = Vector2.ONE * lerpf(frag.start_scale, frag.end_scale, t)
	frag.quad.set_morph_amount(_eased(t))
	frag.quad.set_alpha(1.0 - smoothstep(fx_config.fragment_fade_start, 1.0, t))
