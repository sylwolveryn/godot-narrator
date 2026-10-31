class_name MenuGlyphView
extends Node3D
## Presentation of the in-world menu (task-018): the menu is built from the surroundings. When MenuController opens it
## (SignalBus.menu_opened) glyphs of the floor and the walls around the player lift off and fly, Spike B style, into a
## framed list of readable items above the player; when it closes (menu_closed) they fly back. ONE MultiMesh
## (shaders/glyph_menu.gdshader, one draw call, hidden while closed). The instance buffer is written once per opening,
## the flight and the warm selection highlight are evaluated in the vertex shader from a few uniforms, so a settled
## menu costs no CPU per frame. While the glyphs are away the floor and walls around the player dim (a uniform of the
## world material), so the gaps read as "taken from the surroundings".
## It only presents: it never writes data. The pointer (hover / click on an item) is reported upward on
## SignalBus.menu_item_pointed; MenuController decides what it means.

const MENU_SHADER: String = "res://shaders/glyph_menu.gdshader"
const QUAD_EXTENT: float = 2.0
## Half the world: the bounding box of the menu never culls it (its place is a uniform, not the node transform).
const CULL_HALF_EXTENT: float = 500.0
## A time far past every glyph's landing: the settled state.
const SETTLED: float = 1000.0
## Instance kinds (see the shader).
const KIND_FLOOR: float = 0.0
const KIND_WALL: float = 1.0
const KIND_MARKER: float = 2.0
const KIND_PANEL: float = 3.0
const NO_ITEM: float = -1.0
## Height of borrowed floor glyphs above the floor, and the in-cell scatter of their start (cell fraction).
const FLOOR_LIFT: float = 0.03
const CELL_SCATTER: float = 0.9
## The glyph used for characters the atlas does not know.
const MISSING_GLYPH: String = "?"
## Panel delay and duration (seconds): it arrives with the first glyphs.
const PANEL_DELAY: float = 0.05
const PANEL_DURATION: float = 0.5
## Panel margin beyond the frame (world units).
const PANEL_MARGIN: float = 0.3

enum State { HIDDEN, OPEN, CLOSING }

@export var config: MenuConfig
@export var fx_config: GlyphFxConfig
@export var player: Player
@export var player_config: PlayerConfig
@export var map_loader: MapLoader
@export var world: WorldConfig
## The glyph-surface material of the world: its `lift_zone` uniform dims the surroundings while the glyphs are away.
@export var surface_material: ShaderMaterial

var state: State = State.HIDDEN

var _viewport: SubViewport
var _painter: PlayerGlyphView.AtlasPainter
var _multimesh: MultiMesh
var _instance: MultiMeshInstance3D
var _material: ShaderMaterial
var _slot_of: Dictionary = {}
var _rng := RandomNumberGenerator.new()

var _open_t: float = SETTLED
var _open_total: float = 0.0
var _close_t: float = -1.0
var _select_t: float = SETTLED
var _selected: int = 0
var _lift: float = 0.0
var _lift_centre := Vector2.ZERO
var _anchor: Vector3 = Vector3.ZERO
var _centre: Vector3 = Vector3.ZERO
var _hover: int = -1
var _atlas_grid: Vector2 = Vector2.ONE
## Per item: centre offset on the camera plane, and the half size of its click area (world units).
var _item_centre: PackedVector2Array = PackedVector2Array()
var _item_half: Vector2 = Vector2.ZERO
var _cells_floor: PackedVector2Array = PackedVector2Array()
var _cells_wall: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	top_level = true
	if config == null:
		config = MenuConfig.new()
	if fx_config == null:
		fx_config = GlyphFxConfig.new()
	if player_config == null:
		player_config = PlayerConfig.new()
	if world == null:
		world = WorldConfig.new()
	_rng.randomize()
	_build_atlas()
	_build_instance()
	set_process(false)
	SignalBus.menu_opened.connect(_on_menu_opened)
	SignalBus.menu_closed.connect(_on_menu_closed)
	SignalBus.menu_selection_changed.connect(_on_selection_changed)


func _process(delta: float) -> void:
	var active: bool = false
	if state == State.OPEN and _open_t < _open_total:
		_open_t += delta
		_material.set_shader_parameter(&"open_t", _open_t)
		active = true
	elif state == State.CLOSING:
		_close_t += delta
		_material.set_shader_parameter(&"close_t", _close_t)
		active = true
		if _close_t >= config.return_total():
			state = State.HIDDEN
			_instance.visible = false
			active = false
	if _select_t < config.select_duration:
		_select_t += delta
		_material.set_shader_parameter(&"select_t", _select_t)
		active = true
	if _step_lift(delta):
		active = true
	set_process(active)


func _input(event: InputEvent) -> void:
	if state != State.OPEN:
		return
	if event is InputEventMouseMotion:
		var index: int = _item_at((event as InputEventMouseMotion).position)
		if index != _hover:
			_hover = index
			if index >= 0:
				SignalBus.menu_item_pointed.emit(index, false)
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			var index: int = _item_at(click.position)
			if index >= 0:
				SignalBus.menu_item_pointed.emit(index, true)
				get_viewport().set_input_as_handled()


## True from the opening until the glyphs are back on the ground.
func is_shown() -> bool:
	return state != State.HIDDEN


## True while the menu is open and every glyph has landed.
func is_settled() -> bool:
	return state == State.OPEN and _open_t >= _open_total


## Number of glyph instances of the current menu (letters, pointers, frame, panel).
func glyph_count() -> int:
	return _multimesh.instance_count if _multimesh != null else 0


## Seconds from opening until every glyph has landed.
func open_total() -> float:
	return _open_total


## The 0..1 amount the surroundings are dimmed by (0 closed, 1 fully open).
func lift_amount() -> float:
	return _lift


## Screen position of the centre of item `index` (for tools and the pointer test).
func item_screen_position(index: int) -> Vector2:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null or index < 0 or index >= _item_centre.size():
		return Vector2.ZERO
	var px: Vector2 = _screen_scale(cam)
	var origin: Vector2 = cam.unproject_position(_centre)
	return origin + Vector2(_item_centre[index].x * px.x, -_item_centre[index].y * px.y)


func _on_menu_opened(labels: PackedStringArray, selected: int) -> void:
	if player == null or labels.is_empty():
		return
	_selected = selected
	_hover = -1
	_build_menu(labels)
	_open_t = 0.0
	_close_t = -1.0
	_select_t = SETTLED
	_material.set_shader_parameter(&"open_t", 0.0)
	_material.set_shader_parameter(&"close_t", -1.0)
	_material.set_shader_parameter(&"selected", float(selected))
	_material.set_shader_parameter(&"prev_selected", float(selected))
	_material.set_shader_parameter(&"select_t", SETTLED)
	_material.set_shader_parameter(&"anchor", _anchor)
	_material.set_shader_parameter(&"menu_centre", _centre)
	_instance.visible = true
	state = State.OPEN
	set_process(true)


func _on_menu_closed() -> void:
	if state != State.OPEN:
		return
	state = State.CLOSING
	_close_t = 0.0
	_material.set_shader_parameter(&"close_t", 0.0)
	set_process(true)


func _on_selection_changed(index: int) -> void:
	if state != State.OPEN:
		return
	_material.set_shader_parameter(&"prev_selected", float(_selected))
	_selected = index
	_material.set_shader_parameter(&"selected", float(index))
	_select_t = 0.0
	_material.set_shader_parameter(&"select_t", 0.0)
	set_process(true)


## Moves the dim of the surroundings towards open (1) or closed (0). Returns true while it is still moving.
func _step_lift(delta: float) -> bool:
	var target: float = 1.0 if state == State.OPEN else 0.0
	if is_equal_approx(_lift, target):
		return false
	var time: float = config.lift_in if target > _lift else config.lift_out
	_lift = move_toward(_lift, target, delta / maxf(time, 0.001))
	if surface_material != null:
		var smooth: float = _lift * _lift * (3.0 - 2.0 * _lift)
		surface_material.set_shader_parameter(&"lift_zone", Vector4(_lift_centre.x, _lift_centre.y, config.lift_radius, config.lift_dim * smooth))
	return not is_equal_approx(_lift, target)


## Item under a screen position (viewport coordinates), or -1.
func _item_at(screen: Vector2) -> int:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return -1
	var px: Vector2 = _screen_scale(cam)
	var origin: Vector2 = cam.unproject_position(_centre)
	var local := Vector2((screen.x - origin.x) / px.x, -(screen.y - origin.y) / px.y)
	for i in _item_centre.size():
		var d: Vector2 = local - _item_centre[i]
		if absf(d.x) <= _item_half.x and absf(d.y) <= _item_half.y:
			return i
	return -1


## Pixels per world unit on the camera plane (x right, y up).
func _screen_scale(cam: Camera3D) -> Vector2:
	var b: Basis = cam.global_transform.basis
	var origin: Vector2 = cam.unproject_position(_centre)
	var right: Vector2 = cam.unproject_position(_centre + b.x) - origin
	var up: Vector2 = origin - cam.unproject_position(_centre + b.y)
	return Vector2(maxf(absf(right.x), 0.001), maxf(absf(up.y), 0.001))


# ---------------------------------------------------------------------------------------------------------------------
# Building the menu


## Lays out the labels, the pointers, the frame and the panel, picks where each glyph comes from and writes the buffer.
func _build_menu(labels: PackedStringArray) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	var right := Vector3.RIGHT
	var up := Vector3.UP
	if cam != null:
		right = cam.global_transform.basis.x
		up = cam.global_transform.basis.y
	_anchor = player.global_position
	_centre = _anchor + Vector3.UP * player_config.glyph_height + up * config.centre_up
	_lift_centre = Vector2(_anchor.x, _anchor.z)
	var slots: Array[Dictionary] = _layout(labels)
	var count: int = slots.size()
	_multimesh.instance_count = count
	var starts: Array[Dictionary] = _pick_sources(count, right)
	# The panel (slot 0) is drawn first so it only backs the glyphs; the rest is sorted by x to pair with the sorted sources.
	var panel_slot: Dictionary = slots.pop_front()
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["pos"].x < b["pos"].x)
	slots.push_front(panel_slot)
	var total: float = 0.0
	for i in count:
		var slot: Dictionary = slots[i]
		var start: Dictionary = starts[i]
		var kind: float = slot["kind"]
		if kind != KIND_PANEL and start["wall"] and kind != KIND_MARKER:
			kind = KIND_WALL
		var from_world: Vector3 = _anchor + (start["pos"] as Vector3)
		var to_world: Vector3 = _centre + right * slot["pos"].x + up * slot["pos"].y
		var dur: float = config.open_duration * (0.85 + _rng.randf() * 0.3)
		var delay: float = float(slot["order"]) * config.open_stagger + _rng.randf() * config.open_jitter
		var spin: float = maxf(roundf(config.spin_turns * (0.4 + _rng.randf() * 0.6)), 1.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var arc: float = config.arc_height + from_world.distance_to(to_world) * config.arc_per_distance
		var from_slot: float = float(_slot_for(start["glyph"]))
		var to_slot: float = float(_slot_for(slot["glyph"]))
		var half: float = slot["size"] / config.glyph_fill * 0.5
		var seed_value: float = _rng.randf()
		var basis: Basis
		var origin: Vector3
		if kind == KIND_PANEL:
			delay = PANEL_DELAY
			dur = PANEL_DURATION
			var panel_half: Vector2 = slot["half"]
			basis = Basis(Vector3(0.0, 0.0, 1.0), Vector3.ZERO, Vector3(delay, dur, 0.0))
			origin = Vector3(panel_half.x, panel_half.y, seed_value)
		else:
			basis = Basis(Vector3(slot["pos"].x, slot["pos"].y, half), start["pos"], Vector3(delay, dur, spin))
			origin = Vector3(from_slot, to_slot, seed_value)
		total = maxf(total, delay + dur)
		_multimesh.set_instance_transform(i, Transform3D(basis, origin))
		_multimesh.set_instance_color(i, slot["color"])
		_multimesh.set_instance_custom_data(i, Color(slot["item"], kind, arc, 0.0))
	_open_total = total


## All instances of the menu as dictionaries (pos on the camera plane relative to the centre, glyph, size, colour,
## item index, kind, order, half extents for the panel).
func _layout(labels: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rows: int = labels.size()
	var longest: int = 0
	for label in labels:
		longest = maxi(longest, label.length())
	var half_w: float = longest * config.advance * 0.5 + config.padding.x
	var half_h: float = (rows - 1) * 0.5 * config.row_height + config.padding.y
	_item_centre.resize(rows)
	_item_half = Vector2(half_w - config.padding.x * 0.35, config.row_height * 0.5)
	var order: int = 0
	var panel_half := Vector2(half_w, half_h) + Vector2.ONE * PANEL_MARGIN
	out.append({"pos": Vector2.ZERO, "glyph": " ", "size": 1.0, "color": config.panel_color, "item": NO_ITEM,
			"kind": KIND_PANEL, "order": 0, "half": panel_half})
	for r in rows:
		var label: String = labels[r]
		var y: float = ((rows - 1) * 0.5 - r) * config.row_height
		_item_centre[r] = Vector2(0.0, y)
		for c in label.length():
			var ch: String = label[c]
			if ch == " ":
				order += 1
				continue
			var x: float = (c - (label.length() - 1) * 0.5) * config.advance
			out.append(_glyph_slot(Vector2(x, y), ch, config.glyph_size, config.item_color, float(r), KIND_FLOOR, order))
			order += 1
		var reach: float = label.length() * config.advance * 0.5 + config.marker_gap
		out.append(_glyph_slot(Vector2(-reach, y), config.marker_left, config.glyph_size, config.selected_color, float(r), KIND_MARKER, order))
		out.append(_glyph_slot(Vector2(reach, y), config.marker_right, config.glyph_size, config.selected_color, float(r), KIND_MARKER, order))
	var nx: int = maxi(int(roundf(half_w * 2.0 / config.frame_step)), 2)
	var ny: int = maxi(int(roundf(half_h * 2.0 / config.frame_step)), 2)
	var frame_order: int = 0
	for ix in range(nx + 1):
		var x: float = -half_w + half_w * 2.0 * ix / nx
		var corner: bool = ix == 0 or ix == nx
		var ch: String = config.frame_corner if corner else config.frame_horizontal
		for edge in [-1.0, 1.0]:
			out.append(_glyph_slot(Vector2(x, edge * half_h), ch, config.frame_size, config.frame_color, NO_ITEM, KIND_FLOOR, frame_order))
		frame_order += 1
	for iy in range(1, ny):
		var y: float = -half_h + half_h * 2.0 * iy / ny
		for edge in [-1.0, 1.0]:
			out.append(_glyph_slot(Vector2(edge * half_w, y), config.frame_vertical, config.frame_size, config.frame_color, NO_ITEM, KIND_FLOOR, frame_order))
		frame_order += 1
	return out


func _glyph_slot(pos: Vector2, glyph: String, size: float, color: Color, item: float, kind: float, order: int) -> Dictionary:
	return {"pos": pos, "glyph": glyph, "size": size, "color": color, "item": item, "kind": kind, "order": order, "half": Vector2.ZERO}


## `count` glyphs borrowed from the floor and the walls around the player: offsets from the anchor, sorted by their x on the
## screen so that flights to x-sorted places never cross.
func _pick_sources(count: int, right: Vector3) -> Array[Dictionary]:
	_collect_cells()
	var out: Array[Dictionary] = []
	for i in count:
		var wall: bool = not _cells_wall.is_empty() and _rng.randf() < config.wall_share
		var pos: Vector3
		var cells: PackedVector2Array = _cells_wall if wall else _cells_floor
		if cells.is_empty():
			var angle: float = _rng.randf() * TAU
			var radius: float = config.source_radius * sqrt(_rng.randf())
			pos = Vector3(cos(angle) * radius, FLOOR_LIFT, sin(angle) * radius)
			wall = false
		else:
			var cell: Vector2 = cells[_rng.randi() % cells.size()]
			var scatter := Vector2(_rng.randf() - 0.5, _rng.randf() - 0.5) * CELL_SCATTER * world.cell_size
			var y: float = world.wall_height + FLOOR_LIFT if wall else FLOOR_LIFT
			pos = Vector3(cell.x + scatter.x - _anchor.x, y, cell.y + scatter.y - _anchor.z)
		var glyphs: String = config.wall_source_glyphs if wall else config.floor_source_glyphs
		out.append({"pos": pos, "wall": wall, "glyph": glyphs[_rng.randi() % glyphs.length()]})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["pos"] as Vector3).dot(right) < (b["pos"] as Vector3).dot(right))
	return out


## World XZ centres of the floor and wall cells within the source radius of the player.
func _collect_cells() -> void:
	_cells_floor.clear()
	_cells_wall.clear()
	if map_loader == null or map_loader.data.is_empty():
		return
	var reach: int = ceili(config.source_radius / world.cell_size)
	var centre: Vector2i = map_loader.world_to_cell(_anchor)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var cell := Vector2i(centre.x + dx, centre.y + dy)
			if not map_loader.data.in_bounds(cell):
				continue
			var at: Vector3 = map_loader.cell_to_world(cell)
			if Vector2(at.x - _anchor.x, at.z - _anchor.z).length() > config.source_radius:
				continue
			var type: StringName = map_loader.data.type_at(cell)
			if type == MapLegend.WALL:
				_cells_wall.append(Vector2(at.x, at.z))
			elif type == MapLegend.FLOOR or type == MapLegend.SPAWN:
				_cells_floor.append(Vector2(at.x, at.z))


func _slot_for(glyph: String) -> int:
	if _slot_of.has(glyph):
		return _slot_of[glyph]
	return _slot_of.get(MISSING_GLYPH, 0)


# ---------------------------------------------------------------------------------------------------------------------
# Atlas and instance


## Rasterises every glyph the menu can show (all item labels, pointers, frame, the floor and wall glyphs it borrows) once.
func _build_atlas() -> void:
	var glyphs := PackedStringArray()
	_slot_of.clear()
	_add_slot(glyphs, MISSING_GLYPH)
	for item in config.items:
		if item == null:
			continue
		for ch in item.label + item.alt_label:
			_add_slot(glyphs, ch)
	for text in [config.frame_corner, config.frame_horizontal, config.frame_vertical, config.marker_left, config.marker_right,
			config.floor_source_glyphs, config.wall_source_glyphs, " "]:
		for ch in text:
			_add_slot(glyphs, ch)
	var cols: int = ceili(sqrt(float(glyphs.size())))
	var rows: int = ceili(float(glyphs.size()) / float(cols))
	_viewport = SubViewport.new()
	_viewport.name = "MenuAtlas"
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	_viewport.size = Vector2i(cols, rows) * fx_config.atlas_tile_px
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	_painter = PlayerGlyphView.AtlasPainter.new()
	_painter.name = "Painter"
	var font := SystemFont.new()
	font.font_names = config.font_names
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.font_weight = config.font_weight
	_painter.font = font
	_painter.tile = fx_config.atlas_tile_px
	_painter.font_px = int(fx_config.atlas_tile_px * fx_config.font_fill)
	_painter.glyphs = glyphs
	_painter.cols = cols
	_viewport.add_child(_painter)
	_atlas_grid = Vector2(cols, rows)


func _add_slot(glyphs: PackedStringArray, glyph: String) -> void:
	if _slot_of.has(glyph):
		return
	_slot_of[glyph] = glyphs.size()
	glyphs.append(glyph)


func _build_instance() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(QUAD_EXTENT, QUAD_EXTENT)
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.use_custom_data = true
	_multimesh.mesh = quad
	_material = ShaderMaterial.new()
	_material.shader = load(MENU_SHADER) as Shader
	_material.render_priority = 3
	_material.set_shader_parameter(&"glyph_atlas", _viewport.get_texture())
	_material.set_shader_parameter(&"atlas_grid", _atlas_grid)
	_material.set_shader_parameter(&"glyph_fill", config.glyph_fill)
	_material.set_shader_parameter(&"outline_color", config.outline_color)
	_material.set_shader_parameter(&"outline_width", config.outline_width)
	_material.set_shader_parameter(&"return_dur", config.return_duration)
	_material.set_shader_parameter(&"return_jitter", config.return_jitter)
	_material.set_shader_parameter(&"select_dur", config.select_duration)
	_material.set_shader_parameter(&"select_swell", config.select_swell)
	_material.set_shader_parameter(&"select_color", _rgb(config.selected_color))
	_material.set_shader_parameter(&"glow_color", _rgb(config.glow_color))
	_material.set_shader_parameter(&"glow_strength", config.glow_strength)
	_material.set_shader_parameter(&"floor_color", _rgb(config.floor_source_color))
	_material.set_shader_parameter(&"wall_color", _rgb(config.wall_source_color))
	_material.set_shader_parameter(&"start_ratio", config.start_size_ratio)
	_material.set_shader_parameter(&"pop", config.pop)
	_material.set_shader_parameter(&"flash", config.flash)
	_material.set_shader_parameter(&"overshoot", config.overshoot)
	_material.set_shader_parameter(&"bob_amount", config.bob_amount)
	_material.set_shader_parameter(&"bob_speed", config.bob_speed)
	_material.set_shader_parameter(&"panel_alpha", config.panel_alpha)
	_material.set_shader_parameter(&"panel_color", _rgb(config.panel_color))
	_instance = MultiMeshInstance3D.new()
	_instance.name = "Menu"
	_instance.multimesh = _multimesh
	_instance.material_override = _material
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_instance.custom_aabb = AABB(Vector3.ONE * -CULL_HALF_EXTENT, Vector3.ONE * CULL_HALF_EXTENT * 2.0)
	_instance.visible = false
	add_child(_instance)


func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
