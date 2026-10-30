class_name GlyphOverlay
extends CanvasLayer
## Overlay layer (>= 10, above the ASCII post-process) that draws crisp glyphs the shader
## must not touch. For now: the player's identity glyph, positioned each frame at the
## camera projection of the player's world position (decision-001).

@export var camera_rig: CameraRig
@export var player: Player
@export var player_config: PlayerConfig

var _label: Label
var _settings: LabelSettings


func _ready() -> void:
	if player_config == null:
		player_config = PlayerConfig.new()
	_settings = LabelSettings.new()
	var font := SystemFont.new()
	font.font_names = player_config.font_names
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_settings.font = font
	_settings.font_size = player_config.font_size
	_settings.font_color = player_config.glyph_color
	_settings.outline_color = player_config.outline_color
	_settings.outline_size = player_config.outline_size
	_label = Label.new()
	_label.name = "PlayerGlyph"
	_label.label_settings = _settings
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	add_child(_label)
	if player != null:
		player.identity_changed.connect(_on_identity_changed)
		if player.identity_glyph != "":
			_on_identity_changed(player.identity_glyph)


func _process(_delta: float) -> void:
	if not _label.visible or camera_rig == null or player == null:
		return
	var screen_pos: Vector2 = camera_rig.camera.unproject_position(player.global_position)
	_label.position = (screen_pos - _label.size * 0.5).round()


func _on_identity_changed(glyph: String) -> void:
	_label.text = glyph
	_label.reset_size()
	_label.visible = glyph != ""
