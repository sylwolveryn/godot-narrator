class_name GlyphAnimView
extends Node
## Feeds the DB-driven glyph animation (task-054) into the glyph-surface material: per surface type a set of
## characters that cycle, a colour palette they blend through, and how many glyphs animate near the player and far
## from it. Values come from the DB table `glyph_anim` (GameDatabase.tables_loaded, so a reload from the god tool
## applies at once). The characters are rasterised once per change into a small atlas (one SubViewport render).
## Presentation only: it reads the DB copy and sets shader uniforms.

## Shader uniform names.
const U_ATLAS: StringName = &"anim_atlas"
const U_PARAMS: StringName = &"anim_params"
const U_SPEED: StringName = &"anim_speed"
const U_PALETTE: StringName = &"anim_palette"
const TABLE: String = "glyph_anim"


class Painter extends Node2D:
	var font: Font
	var rows: PackedStringArray = []
	var cfg: GlyphAnimConfig

	func _draw() -> void:
		var cell: float = float(cfg.cell_px)
		draw_rect(Rect2(Vector2.ZERO, Vector2(cfg.max_chars, rows.size()) * cell), Color.BLACK)
		for row in rows.size():
			var glyphs: String = rows[row]
			for col in mini(glyphs.length(), cfg.max_chars):
				var code: int = glyphs.unicode_at(col)
				var adv: float = font.get_char_size(code, cfg.font_px).x
				var pos := Vector2(col * cell + (cell - adv) * 0.5, row * cell + cell * 0.5 + cfg.font_px * cfg.baseline_drop)
				font.draw_char(get_canvas_item(), pos, code, cfg.font_px, Color.WHITE)


@export var config: GlyphAnimConfig
@export var database: GameDatabase
@export var map_loader: MapLoader

var _viewport: SubViewport
var _painter: Painter
var _rows: Array = []


func _ready() -> void:
	if config == null:
		config = GlyphAnimConfig.new()
	_viewport = SubViewport.new()
	_viewport.name = "AnimAtlas"
	_viewport.size = Vector2i(config.max_chars, config.surface_ids.size()) * config.cell_px
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	_painter = Painter.new()
	_painter.cfg = config
	var font := SystemFont.new()
	font.font_names = config.font_names
	_painter.font = font
	_viewport.add_child(_painter)
	if database != null:
		database.tables_loaded.connect(_on_tables_loaded)
		_rows = database.rows(TABLE)
	if map_loader != null:
		map_loader.map_built.connect(func(_map: MapData) -> void: apply())
	apply()


## Pushes the current rows into the material and re-renders the character atlas.
func apply() -> void:
	var material: ShaderMaterial = _material()
	var count: int = config.surface_ids.size()
	var params := PackedVector4Array()
	var speed := PackedVector4Array()
	var palette := PackedVector4Array()
	var glyph_rows := PackedStringArray()
	for i in count:
		var row: Dictionary = _row_for(config.surface_ids[i])
		var chars: String = str(row.get("chars", "")).substr(0, config.max_chars)
		var colours: PackedColorArray = parse_palette(str(row.get("palette", "")), config.max_palette)
		var enabled: bool = bool(row.get("enabled", false)) and chars.length() > 0 and colours.size() > 0
		glyph_rows.append(chars)
		params.append(Vector4(float(row.get("near_intensity", 0.0)), float(row.get("far_intensity", 0.0)),
				float(row.get("radius", 1.0)) * _cell_size(), 1.0 if enabled else 0.0))
		speed.append(Vector4(float(row.get("char_speed", 0.0)), float(row.get("color_speed", 0.0)),
				float(chars.length()), float(colours.size())))
		for k in config.max_palette:
			var c: Color = colours[k] if k < colours.size() else Color.BLACK
			palette.append(Vector4(c.r, c.g, c.b, 1.0))
	_painter.rows = glyph_rows
	_painter.queue_redraw()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if material == null:
		return
	material.set_shader_parameter(U_ATLAS, _viewport.get_texture())
	material.set_shader_parameter(U_PARAMS, params)
	material.set_shader_parameter(U_SPEED, speed)
	material.set_shader_parameter(U_PALETTE, palette)
	material.set_shader_parameter(&"anim_brightness", Vector2(config.brightness_dim, config.brightness_bright))


## "#rrggbb,#rrggbb" -> colours (invalid entries skipped), at most `limit`.
static func parse_palette(text: String, limit: int) -> PackedColorArray:
	var out := PackedColorArray()
	for part in text.split(",", false):
		var code: String = part.strip_edges()
		if out.size() >= limit or not Color.html_is_valid(code):
			continue
		out.append(Color.html(code))
	return out


func _row_for(surface: String) -> Dictionary:
	for row: Variant in _rows:
		if row is Dictionary and str((row as Dictionary).get("surface", "")) == surface:
			return row
	return {}


func _material() -> ShaderMaterial:
	return map_loader.surface_material as ShaderMaterial if map_loader != null else null


func _cell_size() -> float:
	return map_loader.world_config.cell_size if map_loader != null and map_loader.world_config != null else 1.0


func _on_tables_loaded(tables: Dictionary) -> void:
	_rows = tables.get(TABLE, [])
	apply()
