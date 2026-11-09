class_name DeathMarksView
extends Node3D
## Death marks (task-093), presentation side. Reads DeathMarks / Invulnerability and the signals; never writes data.
##  - Stains: one texel per map cell (r = strength, g = a per-cell purple / red bias) in the glyph-surface material's
##    `stain_map`; the shader sprays the stained cells' glyphs purple to red (shaders/glyph_surface.gdshader). The
##    texture is rebuilt on a death and on a map build only.
##  - Invulnerability items: a bobbing, glowing ⚛ over each item cell; a fresh item is thrown out of the death spot on
##    an arc. Items placed by the map (legend `I`) appear once their cell is revealed.
##  - Shield: while the player is invulnerable, two rings of small light-blue glyphs (DeathMarksConfig.ring_text) turn
##    around the player on tilted, precessing planes (an energy shield in 3D, no collision); glyphs on the far side
##    are dimmer and smaller, and the shield flickers in its last seconds.
## All glyphs are ONE MultiMesh (GlyphBillboards). Processing stops when there is nothing to draw.

@export var config: DeathMarksConfig
@export var marks: DeathMarks
@export var map_loader: MapLoader
@export var player: Node3D
@export var invulnerability: Invulnerability
## The glyph-surface material of the world (its stain uniforms).
@export var surface_material: ShaderMaterial
## Optional (task-095): an item is drawn only once its cell has been revealed (seen or remembered), so a map's `I`
## does not show through the fog. Null draws every item.
@export var map_reveal: MapReveal

var _glyphs: GlyphBillboards
var _clock: float = 0.0
## Item throws: cell -> [from_position, start clock].
var _throws: Dictionary[Vector2i, Array] = {}
var _image: Image
var _texture: ImageTexture
## Shield glyphs drawn in the last frame (tests).
var shield_drawn: int = 0
## Item glyphs drawn in the last frame (tests).
var items_drawn: int = 0


func _ready() -> void:
	if config == null:
		config = DeathMarksConfig.new()
	_glyphs = GlyphBillboards.new()
	_glyphs.name = "DeathMarkGlyphs"
	add_child(_glyphs)
	var rings: int = config.ring_radii.size()
	_glyphs.setup(config.item_glyph + config.ring_text, config.glyph_font_names, config.glyph_tile_px, config.glyph_font_px,
			config.ring_text.length() * rings + 64, Color(1.0, 1.0, 1.0))
	SignalBus.death_stained.connect(func(_m: StringName, _c: Array[Vector2i], _t: int) -> void: refresh_stains())
	SignalBus.death_stains_reset.connect(func(_m: StringName) -> void:
		_throws.clear()
		refresh_stains()
		_wake())
	SignalBus.invulnerability_item_dropped.connect(func(cell: Vector2i, from_position: Vector3) -> void:
		_throws[cell] = [from_position, _clock]
		_wake())
	SignalBus.invulnerability_item_taken.connect(func(cell: Vector2i) -> void: _throws.erase(cell))
	SignalBus.invulnerability_items_placed.connect(func(_cells: Array[Vector2i]) -> void: _wake())
	SignalBus.invulnerability_changed.connect(func(_a: bool, _r: float) -> void: _wake())
	refresh_stains()
	_wake()


## Glyph quads drawn in the last frame (tests).
func drawn() -> int:
	return _glyphs.drawn


## The stain texture as uploaded (tests); null before the first stain.
func stain_image() -> Image:
	return _image


## Rebuilds the stain texture of the current map from DeathMarks.
func refresh_stains() -> void:
	if surface_material == null or marks == null or map_loader == null or map_loader.data.is_empty():
		return
	var stains: Dictionary = marks.stains()
	if stains.is_empty():
		surface_material.set_shader_parameter(&"stain_style", _style(0.0))
		return
	var w: int = maxi(map_loader.data.width, 1)
	var h: int = maxi(map_loader.data.height, 1)
	if _image == null or _image.get_width() != w or _image.get_height() != h:
		_image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		_texture = null
	_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for cell: Vector2i in stains:
		if cell.x < 0 or cell.y < 0 or cell.x >= w or cell.y >= h:
			continue
		var bias: float = fposmod(sin(float(cell.x) * 12.9898 + float(cell.y) * 78.233) * 43758.5453, 1.0)
		_image.set_pixel(cell.x, cell.y, Color(float(stains[cell]), bias, 0.0, 1.0))
	if _texture == null:
		_texture = ImageTexture.create_from_image(_image)
	else:
		_texture.update(_image)
	surface_material.set_shader_parameter(&"stain_map", _texture)
	surface_material.set_shader_parameter(&"stain_style", _style(1.0))
	surface_material.set_shader_parameter(&"stain_purple", Vector3(config.stain_purple.r, config.stain_purple.g, config.stain_purple.b))
	surface_material.set_shader_parameter(&"stain_red", Vector3(config.stain_red.r, config.stain_red.g, config.stain_red.b))


func _style(on: float) -> Vector4:
	return Vector4(on, config.stain_mix, config.stain_density, config.stain_shimmer_hz)


func _wake() -> void:
	set_process(true)


func _shielded() -> bool:
	return invulnerability != null and invulnerability.is_active() and player != null


func _process(delta: float) -> void:
	_clock += delta
	var items: Dictionary = marks.items() if marks != null else {}
	var shielded: bool = _shielded()
	_glyphs.begin()
	items_drawn = 0
	if map_loader != null:
		for cell: Vector2i in items:
			if map_reveal != null and map_reveal.state_of(cell) == MapReveal.CellState.HIDDEN:
				continue
			_draw_item(cell)
			items_drawn += 1
	shield_drawn = 0
	if shielded:
		_draw_shield()
	_glyphs.end()
	if items.is_empty() and not shielded:
		set_process(false)


func _draw_item(cell: Vector2i) -> void:
	var phase: float = float(cell.x * 5 + cell.y * 3) * 0.41
	var rest: Vector3 = map_loader.cell_to_world(cell) + Vector3.UP * (config.item_hover + sin(_clock * TAU * config.item_bob_hz + phase) * config.item_bob)
	var pos: Vector3 = rest
	if _throws.has(cell):
		var throw: Array = _throws[cell]
		var t: float = clampf((_clock - float(throw[1])) / maxf(config.item_throw_seconds, 0.001), 0.0, 1.0)
		var from: Vector3 = (throw[0] as Vector3) + Vector3.UP * config.item_hover
		pos = from.lerp(rest, ease(t, 0.6)) + Vector3.UP * (4.0 * t * (1.0 - t) * config.item_throw_height)
		if t >= 1.0:
			_throws.erase(cell)
	var pulse: float = 0.5 + 0.5 * sin(_clock * TAU * config.shield_pulse_hz + phase)
	_glyphs.put(pos, config.item_size * (1.0 + 0.1 * pulse), config.item_color, 1.0, _glyphs.column(config.item_glyph),
			config.item_glow * (0.7 + 0.3 * pulse))


func _draw_shield() -> void:
	var text: String = config.ring_text
	var n: int = text.length()
	if n == 0:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	var to_cam: Vector3 = cam.global_basis.z if cam != null else Vector3.BACK
	var centre: Vector3 = player.global_position + Vector3.UP * config.shield_height
	var alpha: float = 1.0 + sin(_clock * TAU * config.shield_pulse_hz) * config.shield_pulse
	if invulnerability.remaining < config.shield_warn_seconds:
		alpha *= 0.55 + 0.45 * signf(sin(_clock * TAU * config.shield_warn_hz))
	var precession: float = deg_to_rad(config.precession_speed) * _clock
	for r in config.ring_radii.size():
		var radius: float = config.ring_radii[r]
		var tilt: float = deg_to_rad(config.ring_tilts[r] if r < config.ring_tilts.size() else 0.0)
		var spin: float = deg_to_rad(config.ring_speeds[r] if r < config.ring_speeds.size() else 0.0) * _clock
		var plane := Basis(Vector3.UP, precession + PI * 0.5 * r) * Basis(Vector3.RIGHT, tilt)
		for k in n:
			var ch: String = text[k]
			if ch == " ":
				continue
			var a: float = spin + TAU * float(k) / float(n)
			var offset: Vector3 = plane * Vector3(cos(a) * radius, 0.0, sin(a) * radius)
			var front: float = clampf(offset.dot(to_cam) / maxf(radius, 0.001) * 0.5 + 0.5, 0.0, 1.0)
			var size: float = config.shield_glyph_size * lerpf(config.shield_back_size, 1.0, front)
			var glyph_alpha: float = clampf(alpha * lerpf(config.shield_back_alpha, 1.0, front), 0.0, 1.0)
			if _glyphs.put(centre + offset, size, config.shield_color, glyph_alpha, _glyphs.column(ch), config.shield_glow):
				shield_drawn += 1
