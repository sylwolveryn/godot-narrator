class_name LargeObjectView
extends Node3D
## Draws the merged multi-cell props of the built map (task-058) as ASCII art: one "piece" Node3D per merged object,
## centred on its footprint and scaled by it (x by the cells wide, y by the cells deep), holding one Y-billboard
## Label3D per colour layer of its LargeObjectDef (typically 2-3 draw calls per object). The art of a 1x1 object is
## `art_width_ratio` cells wide; a 2x2 object is twice as wide and twice as tall.
## Reveal (like the halos and the world mesh): hidden until any cell of the footprint is seen or remembered, drawn in
## the def's memory tint while only remembered, fading between the looks. Animated layers (e.g. water) cycle their
## glyphs at the def's low anim_fps from pre-built texts (no string building at run time).
## Layered clarity (task-066): behind its colour layers every piece has a dark silhouette "backing" label (the art with
## every drawn or enclosed character replaced by a block, plus a wide outline), so the floor glyphs no longer show
## through the gaps of the art. Its opacity follows the selected language's understanding
## (SignalBus.language_understanding_changed): hidden at 0 (the old look), opaque at 1.
## Destroyed props (task-073, LargeObjectPlacement.destroyed) are hidden until they are restored.
## Statues (task-101, LargeObjectDef.views): a def with pre-baked views is drawn as a statue that turns with the camera
## instead: its labels face the camera fully and show the baked view nearest to the camera yaw (texts pre-built per
## view, swapped only when the yaw crosses a view boundary), anchored so the model's base centre lands on the footprint
## centre; the billboard is pushed towards the camera along the view ray by the model's front depth (an orthographic
## camera sees no difference) so it never sinks into the floor or the basin. A def with `basin` also gets the real basin
## geometry (FountainBasin) fitted to the footprint, so the fountain stays on its cells at every yaw.
## Reads MapLoader and MapReveal; never writes data.

@export var map_loader: MapLoader
## Optional: without it every piece is shown as seen.
@export var map_reveal: MapReveal
## Optional (statues): the camera yaw picks the baked view; without it view 0 is shown.
@export var camera_rig: Node3D

## Fallback width of one glyph in font pixels as a fraction of the font size (when the font cannot be measured).
const GLYPH_ASPECT_FALLBACK: float = 0.6
## Looks closer than this to their target snap to it.
const LOOK_EPSILON: float = 0.002
const SPACE: String = " "

## Colour of the silhouette backing at full understanding (the scene's background colour hides the floor glyphs).
@export var backing_color: Color = Color(0.008, 0.01, 0.018, 1.0)
## Character drawn for every covered art cell of the backing.
@export var backing_char: String = "█"
## Outline of the backing label in font pixels (closes the gaps between lines and characters).
@export_range(0, 64) var backing_outline: int = 16
## Statues: the widest gap (cells) between drawn cells of a row that the backing closes.
@export_range(0, 16) var statue_backing_gap: int = 3
## Backing opacity = understanding ^ backing_exponent.
@export var backing_exponent: float = 1.0


class Piece:
	var placement: LargeObjectPlacement
	var def: LargeObjectDef
	var root: Node3D
	var labels: Array[Label3D] = []
	## Dark silhouette behind the colour layers (layered clarity); hidden while the clarity is 0.
	var backing: Label3D
	var layers: PackedStringArray = PackedStringArray()
	## Current and target visibility (0 hidden, 1 shown) and seen fraction (0 remembered, 1 seen).
	## Statue (task-101): the node holding the labels (pushed towards the camera), its shown view, its size (world).
	var statue: Node3D
	var views: LargeObjectViews
	var view: int = -1
	var unit: float = 1.0
	var basin: MeshInstance3D
	var basin_material: ShaderMaterial
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
## Backing opacity (0..1) from the language understanding.
var _clarity: float = 0.0
var _backing_texts: Dictionary[LargeObjectDef, String] = {}
## Statues: per def, per view: layer -> PackedStringArray of texts (one per animation step), and the backing texts.
var _view_texts: Dictionary[LargeObjectViews, Array] = {}
var _view_backings: Dictionary[LargeObjectViews, PackedStringArray] = {}
var _statue_count: int = 0
var _last_yaw: float = INF
var _last_cam_basis: Basis = Basis()


func _ready() -> void:
	set_process(false)
	SignalBus.run_started.connect(_on_run_started)
	SignalBus.language_understanding_changed.connect(_on_understanding_changed)
	SignalBus.destructible_destroyed.connect(func(_k: StringName, rect: Rect2i, _w: Vector3, _c: StringName) -> void: _refresh_piece_at(rect))
	SignalBus.destructible_restored.connect(func(_k: StringName, rect: Rect2i) -> void: _refresh_piece_at(rect))
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
	if _statue_count > 0:
		_step_statues()
	if not _fading and not _animating and _statue_count == 0:
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


## True when the piece is a statue drawn from baked views (task-101).
func piece_is_statue(index: int) -> bool:
	return _pieces[index].statue != null


## The statue node of a piece (labels inside; pushed towards the camera), or null for flat art.
func piece_statue(index: int) -> Node3D:
	return _pieces[index].statue


## The baked view set and the shown view index of a statue piece.
func piece_views(index: int) -> LargeObjectViews:
	return _pieces[index].views


func piece_view(index: int) -> int:
	return _pieces[index].view


## The basin geometry of a piece, or null.
func piece_basin(index: int) -> MeshInstance3D:
	return _pieces[index].basin


## The silhouette backing label of a piece.
func piece_backing(index: int) -> Label3D:
	return _pieces[index].backing


## Current backing opacity (0..1) from the language understanding.
func clarity() -> float:
	return _clarity


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
	_statue_count = 0
	_last_yaw = INF
	var legend: MapLegend = map_loader.legend
	for placement in map.large_objects:
		var def: LargeObjectDef = legend.large_def(placement.type) if legend != null else null
		if def == null or def.art_lines.is_empty():
			continue
		_pieces.append(_make_piece(placement, def))
	# MapReveal resets its state on the same signal; read it once it has.
	call_deferred(&"_snap_reveal")


func _on_understanding_changed(_language: StringName, understanding: float) -> void:
	_clarity = pow(clampf(understanding, 0.0, 1.0), maxf(backing_exponent, 0.001))
	for piece in _pieces:
		_apply_look(piece)


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
	_last_yaw = INF
	set_process(_animating or _statue_count > 0)


func _make_piece(placement: LargeObjectPlacement, def: LargeObjectDef) -> Piece:
	if def.has_views():
		return _make_statue(placement, def)
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
	var count: int = piece.layers.size()
	# The backing sorts behind every layer and every layer outline.
	piece.backing = _make_label(def, "Backing", -count - 1, backing_outline, _backing_text_of(def))
	piece.backing.visible = false
	piece.root.add_child(piece.backing)
	for i in count:
		var layer: String = piece.layers[i]
		var label: Label3D = _make_label(def, "Layer%d" % i, i, def.outline_size, (texts[layer] as PackedStringArray)[0])
		label.outline_render_priority = i - count
		piece.root.add_child(label)
		piece.labels.append(label)
	piece.root.visible = false
	return piece


## A statue piece (task-101): root on the footprint centre (unscaled), the basin under it, the statue node (uniform
## scale) holding one camera-facing label per layer plus the backing.
func _make_statue(placement: LargeObjectPlacement, def: LargeObjectDef) -> Piece:
	var piece := Piece.new()
	piece.placement = placement
	piece.def = def
	var r: Rect2i = placement.rect
	var cell: float = map_loader.world_config.cell_size
	piece.unit = minf(r.size.x, r.size.y) * cell
	piece.views = def.views_for(minf(r.size.x, r.size.y))
	piece.root = Node3D.new()
	piece.root.name = "%s_%d_%d" % [String(placement.type).to_pascal_case(), r.position.x, r.position.y]
	add_child(piece.root)
	piece.root.position = map_loader.rect_to_world(r) + Vector3.UP * def.art_lift
	if def.basin:
		var size := Vector2(r.size.x, r.size.y) * cell
		piece.basin = MeshInstance3D.new()
		piece.basin.name = "Basin"
		piece.basin.mesh = FountainBasin.build_mesh(size, piece.unit, def)
		piece.basin_material = FountainBasin.make_material(def, piece.unit)
		piece.basin.material_override = piece.basin_material
		piece.basin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.root.add_child(piece.basin)
	piece.statue = Node3D.new()
	piece.statue.name = "Statue"
	piece.root.add_child(piece.statue)
	piece.statue.scale = Vector3.ONE * piece.unit * def.statue_scale
	var view_texts: Array = _view_texts_of(def, piece.views)
	piece.layers = def.layers()
	var count: int = piece.layers.size()
	piece.backing = _make_view_label(def, piece.views, "Backing", -count - 1, backing_outline, _view_backings[piece.views][0])
	piece.backing.visible = false
	piece.statue.add_child(piece.backing)
	for i in count:
		var first: PackedStringArray = (view_texts[0] as Dictionary)[piece.layers[i]]
		var label: Label3D = _make_view_label(def, piece.views, "Layer%d" % i, i, def.outline_size, first[0])
		label.outline_render_priority = i - count
		piece.statue.add_child(label)
		piece.labels.append(label)
	piece.view = 0
	piece.root.visible = false
	_statue_count += 1
	return piece


## A camera-facing label of a statue: one art column is views.col_width wide (before the statue scale), rows are
## stretched to views.row_height, and the anchor cell sits at the node's origin.
func _make_view_label(def: LargeObjectDef, views: LargeObjectViews, label_name: String, priority: int, outline: int, text: String) -> Label3D:
	var font: SystemFont = _font_of(def)
	var advance: float = font.get_char_size("M".unicode_at(0), def.font_size).x
	if advance <= 0.0:
		advance = def.font_size * GLYPH_ASPECT_FALLBACK
	var line: float = font.get_height(def.font_size)
	if line <= 0.0:
		line = def.font_size
	var label := Label3D.new()
	label.name = label_name
	label.font = font
	label.font_size = def.font_size
	label.pixel_size = views.col_width / advance
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.autowrap_trim_flags = 0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.offset = Vector2(-views.anchor.x * advance, views.anchor.y * line)
	label.scale = Vector3(1.0, views.row_height / (line * label.pixel_size), 1.0)
	label.outline_size = outline
	label.render_priority = priority
	label.outline_render_priority = priority - 1
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.text = text
	return label


## Per frame while statues exist; does work only when the camera turned: the view follows the camera yaw (texts swap
## only when it crosses a view boundary) and the statue node follows the camera's view ray.
func _step_statues() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var yaw: float = camera_rig.call(&"current_yaw_degrees") if camera_rig != null else 0.0
	var basis: Basis = cam.global_basis
	if yaw == _last_yaw and basis.is_equal_approx(_last_cam_basis):
		return
	_last_yaw = yaw
	_last_cam_basis = basis
	var back: Vector3 = basis.z.normalized()
	for piece in _pieces:
		if piece.statue == null:
			continue
		var def: LargeObjectDef = piece.def
		piece.statue.position = back * piece.views.front_depth * piece.unit * def.statue_scale
		var view: int = piece.views.index_for_yaw(yaw)
		if view != piece.view:
			piece.view = view
			_show_view(piece)


func _show_view(piece: Piece) -> void:
	var texts: Dictionary = _view_texts[piece.views][piece.view]
	var step: int = int(_anim_clock * piece.def.anim_fps)
	for i in piece.labels.size():
		var frames: PackedStringArray = texts[piece.layers[i]]
		piece.labels[i].text = frames[step % frames.size()]
	piece.backing.text = _view_backings[piece.views][piece.view]


## Per view: layer -> texts (animation steps), built once per def; also fills the per-view backing texts.
func _view_texts_of(def: LargeObjectDef, views: LargeObjectViews) -> Array:
	if _view_texts.has(views):
		return _view_texts[views]
	var out: Array = []
	var backings := PackedStringArray()
	var layers: PackedStringArray = def.layers()
	for v in views.count():
		var lines: PackedStringArray = views.art_lines(v)
		var masks: PackedStringArray = views.mask_lines(v)
		var per: Dictionary = {}
		for layer in layers:
			var frames := PackedStringArray()
			for step in def.layer_steps(layer):
				frames.append(def.lines_layer_text(lines, masks, layer, step))
			per[layer] = frames
		out.append(per)
		backings.append(_solid_silhouette(lines))
	_view_texts[views] = out
	_view_backings[views] = backings
	return out


func _make_label(def: LargeObjectDef, label_name: String, priority: int, outline: int, text: String) -> Label3D:
	var label := Label3D.new()
	label.name = label_name
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
	label.outline_size = outline
	label.render_priority = priority
	label.outline_render_priority = priority - 1
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.text = text
	return label


## The silhouette of the art: a cell is covered when it is drawn, or enclosed by drawn cells left and right on its
## line AND above and below in its column (so the gaps inside the art close, the open sky around it stays open).
func _backing_text_of(def: LargeObjectDef) -> String:
	if _backing_texts.has(def):
		return _backing_texts[def]
	var text: String = _silhouette(def.art_lines)
	_backing_texts[def] = text
	return text


## The backing of a statue: its drawn cells, plus the gaps of at most `statue_backing_gap` cells between drawn cells of
## a row, so the body reads as one solid mass without notches while the open space between a wing and the body stays
## open (a full row fill would paint black slabs over the glowing water).
func _solid_silhouette(lines: PackedStringArray) -> String:
	var out := PackedStringArray()
	for line in lines:
		var row: String = ""
		var last: int = -1
		for c in line.length():
			if line[c] == SPACE:
				continue
			if last >= 0 and c - last - 1 <= statue_backing_gap:
				row += backing_char.repeat(c - last - 1)
			else:
				row += SPACE.repeat(c - row.length())
			row += backing_char
			last = c
		out.append(row)
	return "
".join(out)


func _silhouette(lines: PackedStringArray) -> String:
	var cols: int = 0
	for line in lines:
		cols = maxi(cols, line.length())
	var out := PackedStringArray()
	for r in lines.size():
		var line: String = lines[r]
		var row: String = ""
		for c in line.length():
			var covered: bool = line[c] != SPACE
			if not covered:
				covered = _drawn_in(line, 0, c) and _drawn_in(line, c + 1, line.length()) 						and _drawn_in_column(lines, c, 0, r) and _drawn_in_column(lines, c, r + 1, lines.size())
			row += backing_char if covered else SPACE
		out.append(row)
	return "\n".join(out)


static func _drawn_in(line: String, from: int, to: int) -> bool:
	for c in range(from, mini(to, line.length())):
		if line[c] != SPACE:
			return true
	return false


static func _drawn_in_column(lines: PackedStringArray, col: int, from: int, to: int) -> bool:
	for r in range(from, to):
		if col < lines[r].length() and lines[r][col] != SPACE:
			return true
	return false


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


## A destroyed (or restored) prop (task-073, LargeObjects): its piece hides (or shows again).
func _refresh_piece_at(rect: Rect2i) -> void:
	for piece in _pieces:
		if piece.placement.rect == rect:
			_apply_look(piece)


func _apply_look(piece: Piece) -> void:
	piece.root.visible = piece.vis > 0.0 and not piece.placement.destroyed
	if not piece.root.visible:
		return
	var def: LargeObjectDef = piece.def
	var tint: Color = def.memory_tint.lerp(Color.WHITE, piece.seen)
	tint.a *= piece.vis
	if piece.basin_material != null:
		# Opaque geometry: the fade darkens it instead of making it transparent.
		piece.basin_material.set_shader_parameter(&"tint", Color(tint.r * tint.a, tint.g * tint.a, tint.b * tint.a, 1.0))
	for i in piece.labels.size():
		var label: Label3D = piece.labels[i]
		label.modulate = def.color_of(piece.layers[i]) * tint
		label.outline_modulate = def.outline_color * Color(1.0, 1.0, 1.0, tint.a)
	var back: Color = backing_color
	# A statue is a solid body: its silhouette always hides the floor behind it (flat art keeps the clarity rule).
	back.a *= (1.0 if piece.statue != null else _clarity) * piece.vis
	piece.backing.visible = back.a > 0.0
	piece.backing.modulate = back
	piece.backing.outline_modulate = back


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
		var texts: Dictionary = _texts[def] if piece.statue == null else _view_texts[piece.views][piece.view]
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
