extends SceneTree
## Headless test of the DB glyph ramps (task-079): grapheme splitting (decision-003), spreading clusters over the
## density columns, DB rows -> atlas rows, and that the bundled seed holds a ramp for every atlas row.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_glyph_ramp.gd

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _text(codes: Array) -> String:
	var s := ""
	for c in codes:
		s += String.chr(c)
	return s


func _run() -> void:
	# a, coffin + VS16, family (ZWJ), HU flag, e + combining acute, CJK
	var mixed := _text([0x61, 0x26b0, 0xfe0f, 0x1f468, 0x200d, 0x1f469, 0x200d, 0x1f467, 0x1f1ed, 0x1f1fa, 0x65, 0x301, 0x4e16])
	var g: PackedStringArray = GlyphRampAtlas.graphemes(mixed)
	_check(g.size() == 6, "6 graphemes, got %d" % g.size())
	_check(g.size() == 6 and g[1] == _text([0x26b0, 0xfe0f]) and g[4] == _text([0x65, 0x301]), "clusters keep their parts")
	_check(GlyphRampAtlas.graphemes("").is_empty(), "empty text, no glyphs")

	var cols: PackedStringArray = GlyphRampAtlas.columns_for(PackedStringArray(["a", "b"]), 7)
	_check(cols == PackedStringArray(["a", "a", "a", "a", "b", "b", "b"]), "few glyphs spread sparse to dense: %s" % [cols])
	var many: PackedStringArray = GlyphRampAtlas.columns_for(GlyphRampAtlas.graphemes("0123456789ABCD"), 7)
	_check(many == PackedStringArray(["0", "2", "4", "6", "8", "A", "C"]), "many glyphs are sampled: %s" % [many])
	_check(GlyphRampAtlas.columns_for(PackedStringArray(), 7).is_empty(), "no glyphs, no columns")

	var rows: Dictionary = GlyphRampAtlas.rows_from_table([{"surface": "dirt", "chars": ".o"}, {"surface": "nope", "chars": "x"},
			{"surface": "wall", "chars": "  "}])
	_check(rows == {5: ".o"}, "rows by atlas index, unknown and blank ramps skipped: %s" % [rows])

	var seed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/db/seed.json"))
	var seeded: Dictionary = GlyphRampAtlas.rows_from_table(seed.get(GlyphRampAtlas.TABLE, []))
	_check(seeded.size() == GlyphAtlasSpec.ROWS, "the seed has a ramp for every atlas row (%d)" % seeded.size())

	if _failures.is_empty():
		print("PASS test_glyph_ramp")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_glyph_ramp")
		quit(1)
