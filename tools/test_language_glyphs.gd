extends SceneTree
## Headless test of the per-language obfuscation stand-ins (TASK-100): pools from the language_def rows of the bundled
## seed, config fallbacks for empty pools, the foreign_chance share, the library lookup of the selected language's row,
## the overlay picking the language's stand-ins, and the Dream font drawing the Dream stand-ins.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_language_glyphs.gd

const CONFIG_PATH := "res://resources/narration/narrator_config.tres"
const SEED_PATH := "res://data/db/seed.json"
const SAMPLES := 2000

var _failures: PackedStringArray = []
var _cfg: NarratorConfig


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _run() -> void:
	_cfg = (load(CONFIG_PATH) as NarratorConfig).duplicate()
	var rows: Dictionary = _seed_rows()
	_test_seed(rows)
	_test_fallback()
	_test_foreign_chance(rows)
	_test_library(rows)
	_test_overlay(rows)
	if _failures.is_empty():
		print("PASS test_language_glyphs")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_language_glyphs")
		quit(1)


## language_def rows of the bundled seed by id.
func _seed_rows() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SEED_PATH))
	var out: Dictionary = {}
	if data is Dictionary:
		for row: Variant in (data as Dictionary).get("language_def", []):
			if row is Dictionary:
				out[str((row as Dictionary)["id"])] = row
	return out


func _in_range(ch: String, from: int, to: int) -> bool:
	var c: int = ch.unicode_at(0)
	return c >= from and c <= to


## Every seeded language has its own pools; the scripts match the language.
func _test_seed(rows: Dictionary) -> void:
	for id: String in ["EN_GB", "HU_HU", "ALIEN", "MATRIX", "DREAM", "DE_DE", "RU_RU", "JP_HAN", "JP_KANA"]:
		_check(rows.has(id), "seed has language %s" % id)
		var row: Dictionary = rows.get(id, {})
		_check(str(row.get("static_glyphs", "")) != "" and str(row.get("wild_glyphs", "")) != "", "%s has its own pools" % id)
	var ru := LanguageGlyphs.from_row(rows.get("RU_RU", {}), _cfg)
	for ch in ru.static_glyphs + ru.wild_glyphs:
		_check(_in_range(ch, 0x0400, 0x04FF), "RU_RU pools are Cyrillic ('%s')" % ch)
	var kana := LanguageGlyphs.from_row(rows.get("JP_KANA", {}), _cfg)
	for ch in kana.wild_glyphs:
		_check(_in_range(ch, 0x3040, 0x30FF), "JP_KANA pools are kana ('%s')" % ch)
	var matrix := LanguageGlyphs.from_row(rows.get("MATRIX", {}), _cfg)
	var scripts: Dictionary = {}
	for ch in matrix.wild_glyphs:
		if _in_range(ch, 0xAC00, 0xD7AF):
			scripts["hangul"] = true
		elif _in_range(ch, 0x0600, 0x06FF):
			scripts["arabic"] = true
		elif _in_range(ch, 0xFF61, 0xFF9F) or _in_range(ch, 0x3040, 0x30FF):
			scripts["kana"] = true
		elif _in_range(ch, 0x4E00, 0x9FFF):
			scripts["kanji"] = true
		elif ch.unicode_at(0) >= 0x1F300:
			scripts["emoji"] = true
		elif not _in_range(ch, 0x30, 0x39):
			scripts["symbol"] = true
	_check(scripts.size() == 6, "MATRIX mixes kana, kanji, hangul, arabic, emoji and symbols (%s)" % [scripts.keys()])
	var dream := LanguageGlyphs.from_row(rows.get("DREAM", {}), _cfg)
	_check(dream.font_path != "" and ResourceLoader.exists(dream.font_path), "DREAM font exists (%s)" % dream.font_path)
	var vai: int = 0
	for ch in dream.wild_glyphs:
		if _in_range(ch, 0xA500, 0xA63F):
			vai += 1
	_check(vai * 10 >= dream.wild_glyphs.size() * 8, "DREAM stand-ins are mostly the Dream script (%d / %d)" % [vai, dream.wild_glyphs.size()])


## Empty pools fall back to the NarratorConfig defaults, multi-code-point clusters become one character.
func _test_fallback() -> void:
	var g := LanguageGlyphs.from_row({"static_glyphs": "", "wild_glyphs": " "}, _cfg)
	_check(g.static_glyphs == LanguageGlyphs.split(_cfg.obf_static_glyphs), "empty static pool -> config default")
	_check(g.wild_glyphs == LanguageGlyphs.split(_cfg.obf_wild_glyphs), "blank wild pool -> config default")
	_check(LanguageGlyphs.split("a❤️b") == PackedStringArray(["a", "❤", "b"]), "clusters split to single characters")


## foreign_chance is the share of picks from the shared foreign pool; 0 = never.
func _test_foreign_chance(rows: Dictionary) -> void:
	var ru := LanguageGlyphs.from_row(rows.get("RU_RU", {}), _cfg)
	var foreign: int = 0
	for n in SAMPLES:
		var ch: String = ru.pick_wild(float(n % 97) / 97.0, float(n) / float(SAMPLES), "?")
		if not ru.is_native(ch):
			foreign += 1
	var share: float = float(foreign) / float(SAMPLES)
	_check(absf(share - ru.foreign_chance) < 0.02, "RU_RU foreign share ~%.2f (%.3f)" % [ru.foreign_chance, share])
	var none := LanguageGlyphs.from_row({"static_glyphs": "ab", "wild_glyphs": "ab", "foreign_chance": 0.0}, _cfg)
	var all_native: bool = true
	for n in SAMPLES:
		if not none.is_native(none.pick_static(0.5, float(n) / float(SAMPLES), "?")):
			all_native = false
	_check(all_native, "foreign_chance 0 never picks a foreign glyph")


## The library hands out the selected language's row.
func _test_library(rows: Dictionary) -> void:
	var db := GameDatabase.new()
	db.tables = {"language_def": rows.values()}
	var library: Node = load("res://scripts/narrator/narration_library.gd").new()
	var lib_cfg := NarrationLibraryConfig.new()
	lib_cfg.language = &"RU_RU"
	library.set("database", db)
	library.set("config", lib_cfg)
	_check(str((library.call("language_row") as Dictionary).get("id", "")) == "RU_RU", "language_row follows the selected language")
	_check(str((library.call("language_row", &"DREAM") as Dictionary).get("id", "")) == "DREAM", "language_row by id")
	_check((library.call("language_row", &"NOPE") as Dictionary).is_empty(), "unknown language -> {}")
	# Live reload: a reloaded table (god edit) is what the next beat reads.
	db.tables = {"language_def": [{"id": "RU_RU", "static_glyphs": "Ж", "wild_glyphs": "Ж", "foreign_chance": 0.0}]}
	var edited := LanguageGlyphs.from_row(library.call("language_row"), _cfg)
	_check(edited.pick_wild(0.3, 0.9, "?") == "Ж", "an edited language_def row takes effect on the next beat")
	library.free()
	db.free()


## The overlay shows the language's stand-ins and draws the Dream ones with the Dream font.
func _test_overlay(rows: Dictionary) -> void:
	var overlay: CanvasLayer = load("res://scripts/narrator/narration_overlay.gd").new()
	overlay.set("config", _cfg)
	root.add_child(overlay)
	var beat := NarrationBeat.new()
	beat.text = "Did you see the wall"
	beat.layer = NarrationBeat.Layer.NARRATOR
	var ru := LanguageGlyphs.from_row(rows.get("RU_RU", {}), _cfg)
	var cyrillic: int = 0
	var total: int = 0
	for u: float in [0.05, 0.2]:
		overlay.call("show_beat", beat, 0.0, "", u, ru)
		for i in 30:
			overlay.call("advance", 0.05)
			var shown: String = overlay.call("shown_text")
			for k in shown.length():
				total += 1
				if _in_range(shown[k], 0x0400, 0x04FF):
					cyrillic += 1
	_check(cyrillic * 10 >= total * 8, "RU_RU line obfuscated with Cyrillic (%d / %d)" % [cyrillic, total])

	var dream := LanguageGlyphs.from_row(rows.get("DREAM", {}), _cfg)
	overlay.call("show_beat", beat, 0.0, "", 0.2, dream)
	overlay.call("advance", 0.05)
	var dream_font: Font = overlay.get("_glyph_font")
	_check(dream_font != null, "DREAM font loaded")
	_check(overlay.call("_font_of", dream.wild_glyphs[0]) == dream_font, "Dream stand-ins drawn with the Dream font")
	_check(overlay.call("_font_of", "a") != dream_font, "real letters keep the narration font")
	if dream_font != null:
		_check(dream_font.has_char(dream.wild_glyphs[0].unicode_at(0)), "Dream font has the Dream glyphs")
	overlay.call("show_beat", beat, 0.0, "", 0.2, ru)
	_check(overlay.get("_glyph_font") == null, "a language without a font uses the narration font")
	overlay.free()
