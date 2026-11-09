class_name BrainView
extends Node3D
## The brain form (task-091), presentation: a 2x2 block of Japanese glyphs over the player that keep changing
## (BrainConfig.glyphs, one cell at a time), with a breathing glow outline. Shown only while the entity form is
## EntityForm.BRAIN (SignalBus.entity_form_changed); hidden at a run end until the form is restored. Four Label3D
## billboards; processing only while shown. The world aura is GlyphWorldView's (same BrainConfig).

@export var config: BrainConfig
@export var player: Node3D

var _cells: Array[Label3D] = []
var _next_change: PackedFloat32Array = PackedFloat32Array()
var _clock: float = 0.0
var _rng := RandomNumberGenerator.new()
var _shown: bool = false


func _ready() -> void:
	top_level = true
	if config == null:
		config = BrainConfig.new()
	_rng.randomize()
	var font := SystemFont.new()
	font.font_names = config.font_names
	font.font_weight = config.font_weight
	for i in 4:
		var label := Label3D.new()
		label.name = "Cell%d" % i
		label.font = font
		label.font_size = config.font_size
		label.pixel_size = config.glyph_size / float(config.font_size)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = false
		label.render_priority = 3
		label.outline_render_priority = 2
		label.outline_size = config.glow_size
		label.modulate = config.glyph_color
		label.outline_modulate = config.glow_color
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label.text = _pick()
		add_child(label)
		_cells.append(label)
	_next_change.resize(4)
	for i in 4:
		_next_change[i] = config.cycle_seconds * (i + 1) / 4.0
	visible = false
	set_process(false)
	SignalBus.entity_form_changed.connect(func(form: StringName, _animate: bool) -> void: show_brain(form == EntityForm.BRAIN))
	SignalBus.run_ended.connect(func(_cause: StringName) -> void: show_brain(false))


## Shows or hides the brain block.
func show_brain(on: bool) -> void:
	_shown = on
	visible = on
	set_process(on)
	if on:
		_place()


func is_shown() -> bool:
	return _shown


## The glyphs on show, cell by cell (top left, top right, bottom left, bottom right).
func glyphs() -> PackedStringArray:
	var out := PackedStringArray()
	for c in _cells:
		out.append(c.text)
	return out


func _process(delta: float) -> void:
	_clock += delta
	for i in 4:
		if _clock >= _next_change[i]:
			_cells[i].text = _pick()
			_next_change[i] = _clock + config.cycle_seconds + _rng.randf() * config.cycle_jitter
	var breath: float = 1.0 - config.glow_breath * (0.5 + 0.5 * cos(TAU * _clock / maxf(config.glow_period, 0.01)))
	var glow: Color = config.glow_color
	glow.a *= breath
	for c in _cells:
		c.outline_modulate = glow
	_place()


func _place() -> void:
	if player == null:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	var right: Vector3 = cam.global_transform.basis.x if cam != null else Vector3.RIGHT
	var up: Vector3 = cam.global_transform.basis.y if cam != null else Vector3.UP
	var half: float = (config.glyph_size + config.cell_gap) * 0.5
	var centre: Vector3 = player.global_position + Vector3.UP * config.centre_height
	var offsets: Array[Vector2] = [Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for i in 4:
		_cells[i].global_position = centre + right * offsets[i].x * half + up * offsets[i].y * half


## A random glyph of the pool (a whole grapheme, decision-003).
func _pick() -> String:
	var pool: PackedStringArray = GlyphRampAtlas.graphemes(config.glyphs)
	return pool[_rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else "?"
