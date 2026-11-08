class_name LargeObjectView
extends Node3D
## Draws the merged multi-cell props of the built map (task-058) as ASCII art: one "piece" Node3D per merged object,
## centred on its footprint and scaled by it (x by the cells wide, y by the cells deep), holding one Y-billboard
## Label3D per colour layer of its LargeObjectDef (typically 2-3 draw calls per object). The art of a 1x1 object is
## `art_width_ratio` cells wide; a 2x2 object is twice as wide and twice as tall.
## Reveal (like the halos and the world mesh): hidden until any cell of the footprint is seen or remembered, drawn in
## the def's memory tint while only remembered, fading between the looks. Animated layers (e.g. water) cycle their
## glyphs at the def's low anim_fps from pre-built texts (no string building at run time).
## Reads MapLoader and MapReveal; never writes data.

@export var map_loader: MapLoader
## Optional: without it every piece is shown as seen.
@export var map_reveal: MapReveal

## Fallback width of one glyph in font pixels as a fraction of the font size (when the font cannot be measured).
const GLYPH_ASPECT_FALLBACK: float = 0.6
## Looks closer than this to their target snap to it.
const LOOK_EPSILON: float = 0.002


class Piece:
	var placement: LargeObjectPlacement
	var def: LargeObjectDef
	var root: Node3D
	var labels: Array[Label3D] = []
	var layers: PackedStringArray = PackedStringArray()
	## Current and target visibility (0 hidden, 1 shown) and seen fraction (0 remembered, 1 seen).
	var vis: float = 0.0
	var vis_target: float = 0.0
	var seen: float = 0.0
	var seen_target: float = 0.0


var _pieces: Array[Piece] = []
## Per def: layer -> PackedStringArray of texts (one per animation step; static layers have one).
var _texts: Dictionary[LargeObjectDef, Dictionary] = {}
var _fonts: Dictionary[LargeObjectDef, SystemFont] = {}
var _pixel_sizes: Dictionary[LargeObjectDef, float] = {}
var _anim_clock: float = 0.0
var _fading: bool = false
var _animating: bool = false


func _ready() -> void:
	set_process(false)
	SignalBus.run_started.connect(_on_run_started)
	if map_reveal != null:
		map_reveal.cells_seen.connect(refresh_reveal)
	if map_loader != null:
		map_loader.map_built.connect(_on_map_built)
		if not map_loader.data.is_empty():
			_on_map_built(map_loader.data)


func _process(delta: float) -> void:
	if _fading:
		_step_fade(delta)
	if _animating:
		_step_anim(delta)
	if not _fading and not _animating:
		set_process(false)


## Number of drawn merged objects.
func piece_count() -> int:
	return _pieces.size()


## The Node3D of a piece (its scale is the footprint size in cells).
func piece_node(index: int) -> Node3D:
	return _pieces[index].root


func piece_placement(index: int) -> LargeObjectPlacement:
	return _pieces[index].placement


## The colour layer labels of a piece.
func piece_labels(index: int) -> Array[Label3D]:
	return _pieces[index].labels


## True when the piece is drawn (any footprint cell seen or remembered).
func piece_visible(index: int) -> bool:
	return _pieces[index].root.visible


## World width of the art of a piece (pixel size * measured art width * scale).
func piece_art_width(index: int) -> float:
	var piece: Piece = _pieces[index]
	return _base_width(piece.def) * piece.root.scale.x


## Re-reads the reveal state of every footprint and starts the fades towards it.
func refresh_reveal() -> void:
	for piece in _pieces:
		var state: int = _footprint_state(piece.placement.rect)
		piece.vis_target = 0.0 if state == MapReveal.CellState.HIDDEN else 1.0
		piece.seen_target = 1.0 if state == MapReveal.CellState.SEEN else 0.0
		if not is_equal_approx(piece.vis, piece.vis_target) or not is_equal_approx(piece.seen, piece.seen_target):
			_fading = true
	_update_animating()
	if _fading or _animating:
		set_process(true)


func _on_map_built(map: MapData) -> void:
	for piece in _pieces:
		piece.root.free()
	_pieces.clear()
	var legend: MapLegend = map_loader.legend
	for placement in map.large_objects:
		var def: LargeObjectDef = legend.large_def(placement.type) if legend != null else null
		if def == null or def.art_lines.is_empty():
			continue
		_pieces.append(_make_piece(placement, def))
	# MapReveal resets its state on the same signal; read it once it has.
	call_deferred(&"_snap_reveal")


func _on_run_started(_run_index: int) -> void:
	call_deferred(&"_snap_reveal")


## Reveal state without a fade (map build / run start: the world mesh also jumps to its run-start picture).
func _snap_reveal() -> void:
	refresh_reveal()
	for piece in _pieces:
		piece.vis = piece.vis_target
		piece.seen = piece.seen_target
		_apply_look(piece)
	_fading = false
	_update_animating()
	set_process(_animating)


func _make_piece(placement: LargeObjectPlacement, def: LargeObjectDef) -> Piece:
	var piece := Piece.new()
	piece.placement = placement
	piece.def = def
	var r: Rect2i = placement.rect
	piece.root = Node3D.new()
	piece.root.name = "%s_%d_%d" % [String(placement.type).to_pascal_case(), r.position.x, r.position.y]
	add_child(piece.root)
	piece.root.position = map_loader.rect_to_world(r) + Vector3.UP * def.art_lift
	piece.root.scale = Vector3(float(r.size.x), float(r.size.y), 1.0)
	var texts: Dictionary = _texts_of(def)
	piece.layers = def.layers()
	for i in piece.layers.size():
		var layer: String = piece.layers[i]
		var label := Label3D.new()
		label.name = "Layer%d" % i
		label.font = _font_of(def)
		label.font_size = def.font_size
		label.pixel_size = _pixel_size_of(def)
		label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		# Top-left aligned, placed by hand and without edge-space trimming (Label3D trims the leading / trailing spaces
		# of every line by default, which would shift the sparse layers (eyes, water) against the stone layer).
		label.autowrap_trim_flags = 0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		# Offset is in label pixels and applied in billboard space (a node offset would not turn with the camera).
		label.offset = Vector2(-_base_width(def) * 0.5, _art_height(def)) / _pixel_size_of(def)
		label.outline_size = def.outline_size
		label.render_priority = i
		label.outline_render_priority = i - piece.layers.size()
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label.text = (texts[layer] as PackedStringArray)[0]
		piece.root.add_child(label)
		piece.labels.append(label)
	piece.root.visible = false
	return piece


## Hidden / remembered / seen of a footprint: the best state of its cells.
func _footprint_state(rect: Rect2i) -> int:
	if map_reveal == null:
		return MapReveal.CellState.SEEN
	var best: int = MapReveal.CellState.HIDDEN
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			best = maxi(best, map_reveal.state_of(Vector2i(x, y)))
	return best


func _step_fade(delta: float) -> void:
	var still: bool = false
	for piece in _pieces:
		var rate: float = delta / maxf(piece.def.reveal_fade, 0.001)
		piece.vis = move_toward(piece.vis, piece.vis_target, rate)
		piece.seen = move_toward(piece.seen, piece.seen_target, rate)
		if absf(piece.vis - piece.vis_target) > LOOK_EPSILON or absf(piece.seen - piece.seen_target) > LOOK_EPSILON:
			still = true
		_apply_look(piece)
	_fading = still


func _apply_look(piece: Piece) -> void:
	piece.root.visible = piece.vis > 0.0
	if not piece.root.visible:
		return
	var def: LargeObjectDef = piece.def
	var tint: Color = def.memory_tint.lerp(Color.WHITE, piece.seen)
	tint.a *= piece.vis
	for i in piece.labels.size():
		var label: Label3D = piece.labels[i]
		label.modulate = def.color_of(piece.layers[i]) * tint
		label.outline_modulate = def.outline_color * Color(1.0, 1.0, 1.0, tint.a)


func _update_animating() -> void:
	_animating = false
	for piece in _pieces:
		if piece.vis_target > 0.0 and piece.def.is_animated() and piece.def.anim_fps > 0.0:
			_animating = true
			return


func _step_anim(delta: float) -> void:
	var before: float = _anim_clock
	_anim_clock += delta
	for piece in _pieces:
		if not piece.root.visible:
			continue
		var def: LargeObjectDef = piece.def
		if not def.is_animated() or def.anim_fps <= 0.0:
			continue
		var step: int = int(_anim_clock * def.anim_fps)
		if step == int(before * def.anim_fps):
			continue
		var texts: Dictionary = _texts[def]
		for i in piece.labels.size():
			var frames: PackedStringArray = texts[piece.layers[i]]
			if frames.size() > 1:
				piece.labels[i].text = frames[step % frames.size()]


func _texts_of(def: LargeObjectDef) -> Dictionary:
	if _texts.has(def):
		return _texts[def]
	var out: Dictionary = {}
	for layer in def.layers():
		var frames := PackedStringArray()
		for step in def.layer_steps(layer):
			frames.append(def.layer_text(layer, step))
		out[layer] = frames
	_texts[def] = out
	return out


func _font_of(def: LargeObjectDef) -> SystemFont:
	if not _fonts.has(def):
		var font := SystemFont.new()
		font.font_names = def.font_names
		font.font_weight = def.font_weight
		_fonts[def] = font
	return _fonts[def]


## Pixel size that makes the art of a 1x1 object `art_width_ratio` cells wide.
func _pixel_size_of(def: LargeObjectDef) -> float:
	if _pixel_sizes.has(def):
		return _pixel_sizes[def]
	var cols: int = 0
	for line in def.art_lines:
		cols = maxi(cols, line.length())
	var glyph: float = _font_of(def).get_char_size("M".unicode_at(0), def.font_size).x
	if glyph <= 0.0:
		glyph = def.font_size * GLYPH_ASPECT_FALLBACK
	var size: float = map_loader.world_config.cell_size * def.art_width_ratio / maxf(cols * glyph, 1.0)
	_pixel_sizes[def] = size
	return size


## World height of the art of a 1x1 object (rows * line height).
func _art_height(def: LargeObjectDef) -> float:
	var line: float = _font_of(def).get_height(def.font_size)
	if line <= 0.0:
		line = def.font_size
	return def.art_lines.size() * line * _pixel_size_of(def)


## World width of the art of a 1x1 object.
func _base_width(def: LargeObjectDef) -> float:
	return map_loader.world_config.cell_size * def.art_width_ratio
