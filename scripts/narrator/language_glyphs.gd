class_name LanguageGlyphs
extends RefCounted
## The stand-ins a language's narration is obfuscated with while it is not understood (TASK-100), from its DB row in
## `language_def` (static_glyphs, wild_glyphs, foreign_chance, font). An empty pool falls back to the NarratorConfig
## defaults (obf_static_glyphs / obf_wild_glyphs). A `foreign_chance` share of the picks comes from the shared
## other-alphabet pool (NarratorConfig.obf_foreign_glyphs) instead, so a foreign script only shows now and then.
## Pools are split into single characters once (grapheme clusters, reduced to their first code point because the
## overlay draws one code point per letter).

## Stable first stand-ins and spinning stand-ins of this language.
var static_glyphs: PackedStringArray = PackedStringArray()
var wild_glyphs: PackedStringArray = PackedStringArray()
## Shared other-alphabet pool and the 0..1 share of picks taken from it.
var foreign_glyphs: PackedStringArray = PackedStringArray()
var foreign_chance: float = 0.0
## res:// path of the font the stand-ins are drawn with; empty = the narration font.
var font_path: String = ""
## Own stand-ins as a set (is_native runs per letter per frame).
var _native: Dictionary[String, bool] = {}


## Glyphs of `row` (a language_def row; empty Dictionary = defaults only) with `config`'s fallbacks.
static func from_row(row: Dictionary, config: NarratorConfig) -> LanguageGlyphs:
	var g := LanguageGlyphs.new()
	var static_text: String = str(row.get("static_glyphs", ""))
	var wild_text: String = str(row.get("wild_glyphs", ""))
	g.static_glyphs = split(static_text if not static_text.strip_edges().is_empty() else config.obf_static_glyphs)
	g.wild_glyphs = split(wild_text if not wild_text.strip_edges().is_empty() else config.obf_wild_glyphs)
	g.foreign_glyphs = split(config.obf_foreign_glyphs)
	g.foreign_chance = clampf(float(row.get("foreign_chance", 0.0)), 0.0, 1.0)
	g.font_path = str(row.get("font", "")).strip_edges()
	for ch in g.static_glyphs + g.wild_glyphs:
		g._native[ch] = true
	return g


## The defaults of `config` (no language row).
static func defaults(config: NarratorConfig) -> LanguageGlyphs:
	return from_row({}, config)


## One single-code-point character per grapheme cluster of `text`, blanks dropped.
static func split(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for cluster in GlyphRampAtlas.graphemes(text):
		if cluster.strip_edges().is_empty():
			continue
		out.append(cluster.substr(0, 1))
	return out


## A static stand-in for noise values `k` (which glyph) and `f` (foreign roll), both 0..1.
func pick_static(k: float, f: float, fallback: String) -> String:
	return _pick(static_glyphs, k, f, fallback)


## A spinning stand-in for noise values `k` (which glyph) and `f` (foreign roll), both 0..1.
func pick_wild(k: float, f: float, fallback: String) -> String:
	return _pick(wild_glyphs, k, f, fallback)


## True when `ch` is one of this language's own stand-ins (drawn with its font).
func is_native(ch: String) -> bool:
	return _native.has(ch)


func _pick(pool: PackedStringArray, k: float, f: float, fallback: String) -> String:
	if f < foreign_chance and not foreign_glyphs.is_empty():
		pool = foreign_glyphs
	if pool.is_empty():
		return fallback
	return pool[mini(int(k * pool.size()), pool.size() - 1)]
