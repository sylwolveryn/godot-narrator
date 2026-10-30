class_name GlyphOverlay
extends CanvasLayer
## Overlay layer (>= 10, above the ASCII post-process) that draws crisp glyphs the shader
## must not touch. It draws the player's identity glyph at the camera projection of the
## player's world position (decision-001) and presents corruption: as erosion rises the
## glyph scrambles, jitters, fades and takes the hazard's tint; when the run ends it shatters
## into shards. Erosion arrives by SignalBus signals; this node never writes data.

@export var camera_rig: CameraRig
@export var player: Player
@export var player_config: PlayerConfig
@export var fx_config: GlyphFxConfig

var _label: Label
var _settings: LabelSettings
var _shard_settings: LabelSettings
var _shards: Array[Label] = []
var _rng := RandomNumberGenerator.new()
var _identity: String = ""
var _erosion: float = 0.0
var _tint: Color = Color.WHITE
var _death_tint: Color = Color.WHITE
## While true the glyph is in its pre-burst flash (erosion forced to the maximum).
var _flashing: bool = false
var _dying: bool = false
var _shown: String = ""
var _jitter: Vector2 = Vector2.ZERO
var _reroll_in: float = 0.0
var _tween: Tween
var _shard_tween: Tween


func _ready() -> void:
	if player_config == null:
		player_config = PlayerConfig.new()
	if fx_config == null:
		fx_config = GlyphFxConfig.new()
	_rng.randomize()
	_settings = LabelSettings.new()
	var font := SystemFont.new()
	font.font_names = player_config.font_names
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_settings.font = font
	_settings.font_size = player_config.font_size
	_settings.font_color = player_config.glyph_color
	_settings.outline_color = player_config.outline_color
	_settings.outline_size = player_config.outline_size
	_shard_settings = _settings.duplicate()
	_shard_settings.font_size = roundi(player_config.font_size * fx_config.shard_size_ratio)
	_label = Label.new()
	_label.name = "PlayerGlyph"
	_label.label_settings = _settings
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	add_child(_label)
	SignalBus.erosion_changed.connect(_on_erosion_changed)
	SignalBus.hazard_lethal.connect(_on_hazard_lethal)
	SignalBus.run_ended.connect(_on_run_ended)
	SignalBus.run_started.connect(_on_run_started)
	if player != null:
		player.identity_changed.connect(_on_identity_changed)
		if player.identity_glyph != "":
			_on_identity_changed(player.identity_glyph)


func _process(delta: float) -> void:
	if not _label.visible or camera_rig == null or player == null:
		return
	var level: float = 1.0 if _flashing else _erosion
	_update_scramble(level, delta)
	_label.modulate = Color(1.0, 1.0, 1.0, lerpf(1.0, fx_config.fade_min_alpha, level))
	_settings.font_color = player_config.glyph_color.lerp(_tint, level * fx_config.tint_strength)
	var screen_pos: Vector2 = camera_rig.camera.unproject_position(player.global_position)
	_label.position = (screen_pos - _label.size * 0.5 + _jitter).round()


## Re-rolls the substitute glyph and jitter at a rate that climbs with erosion.
func _update_scramble(level: float, delta: float) -> void:
	if level <= fx_config.scramble_start:
		_set_text(_identity)
		_jitter = Vector2.ZERO
		return
	_reroll_in -= delta
	if _reroll_in > 0.0:
		return
	var rate: float = lerpf(fx_config.scramble_rate_low, fx_config.scramble_rate_high, level)
	_reroll_in = 1.0 / maxf(rate, 0.001)
	var span: float = maxf(1.0 - fx_config.scramble_start, 0.001)
	var chance: float = (level - fx_config.scramble_start) / span * fx_config.scramble_chance_max
	if _rng.randf() < chance:
		_set_text(_random_glyph())
	else:
		_set_text(_identity)
	var reach: float = fx_config.jitter_max * level
	_jitter = Vector2(_rng.randf_range(-reach, reach), _rng.randf_range(-reach, reach))


func _set_text(text: String) -> void:
	if text == _shown:
		return
	_shown = text
	_label.text = text
	_label.reset_size()


func _random_glyph() -> String:
	var pool: String = fx_config.scramble_glyphs
	if pool == "":
		return _identity
	return pool[_rng.randi() % pool.length()]


func _on_identity_changed(glyph: String) -> void:
	_identity = glyph
	_shown = ""
	_set_text(glyph)
	_label.reset_size()
	_label.visible = glyph != ""


func _on_erosion_changed(amount: float, tint: Color) -> void:
	_erosion = amount
	if amount > 0.0:
		_tint = tint


func _on_hazard_lethal(_cause: StringName, tint: Color) -> void:
	_death_tint = tint


func _on_run_started(_run_index: int) -> void:
	if _tween != null:
		_tween.kill()
	if _shard_tween != null:
		_shard_tween.kill()
	_clear_shards()
	_dying = false
	_flashing = false
	_erosion = 0.0
	_death_tint = Color.WHITE
	_tint = Color.WHITE
	_shown = ""


## Flash the glyph to pieces, then let the shards drift out and fade.
func _on_run_ended(_cause: StringName) -> void:
	if _dying or not _label.visible:
		return
	_dying = true
	_flashing = true
	_tint = _death_tint
	_tween = create_tween()
	_tween.tween_interval(fx_config.shatter_flash)
	_tween.tween_callback(_burst)
	_tween.tween_interval(maxf(fx_config.death_duration - fx_config.shatter_flash, 0.0))
	_tween.tween_callback(_clear_shards)


func _burst() -> void:
	_flashing = false
	var centre: Vector2 = _label.position + _label.size * 0.5
	_label.visible = false
	var drift: float = maxf(fx_config.death_duration - fx_config.shatter_flash, 0.01)
	_shard_tween = create_tween().set_parallel(true)
	for i in fx_config.shard_count:
		var shard := Label.new()
		shard.label_settings = _shard_settings.duplicate()
		shard.label_settings.font_color = player_config.glyph_color.lerp(_death_tint, fx_config.tint_strength)
		shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shard.text = _identity if i % 3 == 0 else _random_glyph()
		add_child(shard)
		shard.reset_size()
		_shards.append(shard)
		var angle: float = TAU * (float(i) + _rng.randf()) / float(fx_config.shard_count)
		var reach: float = fx_config.shard_distance * (1.0 - _rng.randf() * fx_config.shard_distance_spread)
		shard.position = (centre - shard.size * 0.5).round()
		var target: Vector2 = shard.position + Vector2.from_angle(angle) * reach
		_shard_tween.tween_property(shard, "position", target, drift).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_shard_tween.tween_property(shard, "modulate:a", 0.0, drift).set_ease(Tween.EASE_IN)


func _clear_shards() -> void:
	for shard in _shards:
		shard.queue_free()
	_shards.clear()
