class_name CannonView
extends Node3D
## Draws the cannons (task-073). Per cannon: a Node3D centred on its footprint and scaled by it (like the gargoyle),
## holding one Y-billboard Label3D per colour layer of the ASCII art (CannonConfig.art: one art set per screen
## direction of the barrel, 8 sets; the set is picked from the cannon's facing seen through the camera's current yaw, so
## the barrel always points where the balls go on screen), plus an aim marker lying on the floor in front of the muzzle
## that turns smoothly with the exact facing. A shot (SignalBus.cannon_fired) flashes the muzzle layer.
## Reveal like the gargoyle: hidden until a footprint cell is seen or remembered, tinted while only remembered.
## Texts are pre-built per direction; per frame only the cannons whose direction index changed get new texts.
## Reads CannonSystem, MapLoader, MapReveal and CameraRig; never writes data.

@export var config: CannonConfig
@export var cannons: CannonSystem
@export var map_loader: MapLoader
## Optional: without it every cannon is shown as seen.
@export var map_reveal: MapReveal
## Optional: the camera yaw (without it the yaw is 0).
@export var camera_rig: CameraRig

const GLYPH_ASPECT_FALLBACK: float = 0.6
const DIRECTIONS: int = 8


class Piece:
	var root: Node3D
	var labels: Array[Label3D] = []
	var aim: Label3D
	var dir_index: int = -1
	var state: int = 0
	var flash: float = 0.0


var _pieces: Array[Piece] = []
## Layer names in label order, and per direction per layer the text.
var _layers: PackedStringArray = PackedStringArray()
var _texts: Array[PackedStringArray] = []
var _font: SystemFont
var _aim_font: SystemFont
var _pixel_size: float = 0.01
var _art_height: float = 1.0


func _ready() -> void:
	if config == null:
		config = CannonConfig.new()
	_font = SystemFont.new()
	_font.font_names = config.font_names
	_font.font_weight = config.font_weight
	_aim_font = SystemFont.new()
	_aim_font.font_names = config.font_names
	_build_texts()
	SignalBus.cannon_fired.connect(_on_fired)
	SignalBus.run_started.connect(func(_i: int) -> void: refresh_reveal.call_deferred())
	if map_reveal != null:
		map_reveal.cells_seen.connect(refresh_reveal)
	if map_loader != null:
		map_loader.map_built.connect(func(_m: MapData) -> void: _rebuild.call_deferred())
	_rebuild.call_deferred()


func _process(delta: float) -> void:
	if cannons == null or _pieces.size() != cannons.cannon_count():
		return
	var yaw: float = camera_rig.current_yaw_degrees() if camera_rig != null else 0.0
	for i in _pieces.size():
		var piece: Piece = _pieces[i]
		if not piece.root.visible:
			continue
		var c: Cannon = cannons.cannon(i)
		var dir: Vector3 = c.direction()
		var index: int = CannonConfig.screen_dir_index(dir, yaw)
		if index != piece.dir_index:
			piece.dir_index = index
			for k in piece.labels.size():
				piece.labels[k].text = _texts[index][k]
		_place_aim(piece, c)
		if piece.flash > 0.0:
			piece.flash = maxf(piece.flash - delta / maxf(config.flash_seconds, 0.001), 0.0)
			_apply_look(piece)


func piece_count() -> int:
	return _pieces.size()


## Direction index (0..7) of the art drawn for cannon `i` (tests).
func piece_dir_index(i: int) -> int:
	return _pieces[i].dir_index


func piece_visible(i: int) -> bool:
	return _pieces[i].root.visible


func piece_node(i: int) -> Node3D:
	return _pieces[i].root


func refresh_reveal() -> void:
	for piece in _pieces:
		_apply_look(piece)


func _rebuild() -> void:
	for piece in _pieces:
		piece.root.free()
	_pieces.clear()
	if cannons == null or map_loader == null or _texts.is_empty():
		return
	_measure()
	for i in cannons.cannon_count():
		_pieces.append(_make_piece(cannons.cannon(i)))
	refresh_reveal()


func _make_piece(c: Cannon) -> Piece:
	var piece := Piece.new()
	var r: Rect2i = c.footprint
	piece.root = Node3D.new()
	piece.root.name = "Cannon_%d_%d" % [r.position.x, r.position.y]
	add_child(piece.root)
	piece.root.position = map_loader.rect_to_world(r)
	piece.root.scale = Vector3(float(r.size.x), float(r.size.y), 1.0)
	for k in _layers.size():
		var label := Label3D.new()
		label.name = "Layer%d" % k
		label.font = _font
		label.font_size = config.font_size
		label.pixel_size = _pixel_size
		label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		label.autowrap_trim_flags = 0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.offset = Vector2(-_base_width() * 0.5, _art_height) / _pixel_size
		label.outline_size = config.outline_size
		label.render_priority = k
		label.outline_render_priority = k - _layers.size()
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label.text = _texts[0][k]
		piece.root.add_child(label)
		piece.labels.append(label)
	# The aim marker lies flat on the floor; it is not a child of the scaled root (its size follows the footprint width).
	var aim := Label3D.new()
	aim.name = "Aim"
	aim.font = _aim_font
	aim.font_size = config.font_size
	aim.text = config.aim_text
	var glyph: float = _aim_font.get_char_size(config.aim_text.unicode_at(0), config.font_size).x if config.aim_text != "" else 0.0
	if glyph <= 0.0:
		glyph = config.font_size * GLYPH_ASPECT_FALLBACK
	aim.pixel_size = map_loader.world_config.cell_size * r.size.x * config.aim_length / maxf(glyph * maxi(config.aim_text.length(), 1), 1.0)
	aim.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	aim.outline_size = config.outline_size / 2
	aim.outline_modulate = config.outline_color
	aim.render_priority = 1
	aim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(aim)
	piece.aim = aim
	piece.root.visible = false
	aim.visible = false
	_place_aim(piece, c)
	return piece


## The aim marker in front of the muzzle, pointing along the exact facing.
func _place_aim(piece: Piece, c: Cannon) -> void:
	var s: float = map_loader.world_config.cell_size
	var d: Vector3 = c.direction()
	var hx: float = c.footprint.size.x * s * 0.5
	var hz: float = c.footprint.size.y * s * 0.5
	var t: float = minf(hx / maxf(absf(d.x), 0.0001), hz / maxf(absf(d.z), 0.0001))
	var len_world: float = s * c.footprint.size.x * config.aim_length
	piece.aim.position = map_loader.rect_to_world(c.footprint) + d * (t + config.aim_offset_cells * s + len_world * 0.5) + Vector3.UP * config.aim_lift
	piece.aim.basis = Basis(Vector3.UP, -c.facing) * Basis(Vector3.RIGHT, -PI * 0.5)


func _on_fired(index: int, _muzzle: Vector3, _dir: Vector3) -> void:
	if index < 0 or index >= _pieces.size():
		return
	_pieces[index].flash = 1.0
	_apply_look(_pieces[index])


func _apply_look(piece: Piece) -> void:
	var rect: Rect2i = Rect2i()
	var i: int = _pieces.find(piece)
	if i >= 0 and cannons != null and i < cannons.cannon_count():
		rect = cannons.cannon(i).footprint
	piece.state = _footprint_state(rect)
	piece.root.visible = piece.state != MapReveal.CellState.HIDDEN
	piece.aim.visible = piece.root.visible
	if not piece.root.visible:
		return
	var tint: Color = Color.WHITE if piece.state == MapReveal.CellState.SEEN else config.memory_tint
	for k in piece.labels.size():
		var layer: String = _layers[k]
		var col: Color = config.layer_colors.get(layer, config.layer_colors.get(" ", Color.WHITE))
		if layer == "m":
			col = col.lerp(config.flash_color, piece.flash) * (1.0 + piece.flash)
		piece.labels[k].modulate = col * tint
		piece.labels[k].outline_modulate = config.outline_color * Color(1.0, 1.0, 1.0, tint.a)
	piece.aim.modulate = config.aim_color * tint


func _footprint_state(rect: Rect2i) -> int:
	if map_reveal == null:
		return MapReveal.CellState.SEEN
	var best: int = MapReveal.CellState.HIDDEN
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			best = maxi(best, map_reveal.state_of(Vector2i(x, y)))
	return best


## Pre-builds the per-direction text of every layer (other layers' glyphs become spaces, rows keep their width).
func _build_texts() -> void:
	_layers = PackedStringArray()
	_texts.clear()
	if config.art.size() < DIRECTIONS:
		return
	for d in DIRECTIONS:
		for line in config.art[d]:
			for ch in line:
				if ch == " ":
					continue
				var layer: String = config.layer_of_char.get(ch, " ")
				if not _layers.has(layer):
					_layers.append(layer)
	_layers.sort()
	for d in DIRECTIONS:
		var per := PackedStringArray()
		for layer in _layers:
			var rows := PackedStringArray()
			for line in config.art[d]:
				var row: String = ""
				for ch in line:
					row += ch if ch != " " and config.layer_of_char.get(ch, " ") == layer else " "
				rows.append(row)
			per.append("\n".join(rows))
		_texts.append(per)


func _columns() -> int:
	var cols: int = 0
	for art_set in config.art:
		for line in art_set:
			cols = maxi(cols, line.length())
	return cols


func _measure() -> void:
	var glyph: float = _font.get_char_size("M".unicode_at(0), config.font_size).x
	if glyph <= 0.0:
		glyph = config.font_size * GLYPH_ASPECT_FALLBACK
	_pixel_size = map_loader.world_config.cell_size * config.art_width_ratio / maxf(_columns() * glyph, 1.0)
	var line: float = _font.get_height(config.font_size)
	if line <= 0.0:
		line = config.font_size
	_art_height = (config.art[0].size() if not config.art.is_empty() else 1) * line * _pixel_size


func _base_width() -> float:
	return map_loader.world_config.cell_size * config.art_width_ratio
