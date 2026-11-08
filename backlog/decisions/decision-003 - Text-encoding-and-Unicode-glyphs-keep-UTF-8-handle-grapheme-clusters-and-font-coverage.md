---
id: decision-003
title: >-
  Text encoding and Unicode glyphs: keep UTF-8, handle grapheme clusters and
  font coverage
date: '2026-11-08T23:16:00Z'
status: accepted
---
## Context

The game wants every visible character as an in-game glyph: Chinese, Japanese (kanji, kana), Korean, kaomoji such as (╯°□°)╯︵ ┻━┻, emoji (including multi-part ones) and symbols. The question was whether the text encoding limits this, and whether a different encoding (UTF-16, UTF-32, GB 18030, UTF-EBCDIC or another) would help.

Text lives in several places, all UTF-8 today:

- GDScript files and `.tres` resources.
- JSON files: `data/db/seed.json`, `narration/event/*.json`, `data/narration/*.json`.
- Map `.txt` files.
- The SpacetimeDB database (strings over HTTP/JSON).

Glyphs are drawn by rasterising characters from system fonts (`SystemFont` with names such as "Consolas" or "Cascadia Mono") into small texture atlases. A SubViewport renders the atlas, and the shaders sample it as a mask.

Three limits matter more than the encoding:

1. **Grapheme clusters.** One visible character can be several code points: emoji with a variation selector (⚰️ = U+26B0 U+FE0F), ZWJ sequences (family 👨‍👩‍👧 = 5 code points), flags (🇭🇺 = 2 regional indicators), skin tones, keycaps and combining marks (e + U+0301 = é). The code splits strings per code point (`String.unicode_at`, `substr`, `String.length`), so these parts are drawn apart.
2. **Font coverage.** A glyph only draws if a font contains it. Consolas has no CJK or emoji. `SystemFont` falls back to fonts that differ per machine.
3. **Colour emoji.** The atlas is a white mask tinted by the shaders, so colour is lost in any case.

## Options considered

### Encoding

| Option | Size per code point | Repertoire | Fit for this project |
|---|---|---|---|
| UTF-8 | 1 to 4 bytes | All 1,114,112 code points | Chosen. ASCII-compatible, no BOM issue. Default for JSON (RFC 8259), HTTP APIs, SpacetimeDB strings, Godot source and `.tres` files. |
| UTF-16 | 2 or 4 bytes (surrogate pairs above U+FFFF) | All code points | Same characters as UTF-8. Has BOM variants. Used by Windows APIs, Java, JavaScript and C#. Would need conversion at every file and DB boundary. |
| UTF-32 | 4 bytes, fixed | All code points | Same characters as UTF-8. Godot's `String` stores `char32_t` internally, so `String.length()` counts code points. Four times the size on disk and on the wire. No file format we use defaults to it. |
| GB 18030 | 1, 2 or 4 bytes | All code points | Chinese national standard. Covers all of Unicode, but needs mapping tables and is not ASCII-transparent in every byte. Godot, JSON and SpacetimeDB do not use it. |
| UTF-EBCDIC | Variable | All code points | IBM mainframe encoding. None of our tools support it. |
| Legacy code pages (Shift_JIS, EUC-KR, Big5, Windows-125x, ISO-8859-x) | Variable | Partial (one script group each) | Cannot cover the full repertoire. Not an option. |
| UTF-7 | Variable | All code points | Obsolete. Not an option. |
| Punycode | Variable | Domain names only | Not for text content. |

No encoding gives more characters than UTF-8. Changing the encoding adds conversion work and gains no repertoire.

### Glyph handling

| Option | What it does | Result |
|---|---|---|
| A. Keep per-code-point splitting (current) | `unicode_at`, `draw_char` per code point | Breaks ZWJ sequences, flags, variation selectors and combining marks. Rejected. |
| B. Split into grapheme clusters, draw each with shaping | `TextServer.string_get_character_breaks` for boundaries, `Font.draw_string` per cluster (HarfBuzz shaping) | Correct clusters. Verified on Godot 4.7.2 (see below). Chosen. |
| C. Use only system fonts | `SystemFont` fallback, no bundled fonts | Different output per machine. Not reproducible. Rejected as the sole approach. |
| D. Bundle a font fallback chain | Ship fonts with the game for Latin mono, symbols, CJK and emoji | Reproducible coverage. Adds size and licence work. Chosen together with B. |

Verified on Godot 4.7.2: `TextServerManager.get_primary_interface()` is the advanced server "ICU / HarfBuzz / Graphite (Built-in)". For the test string `a`, ⚰️, family ZWJ, HU flag, `e` + acute and `世` (13 code points), `string_get_character_breaks()` returned breaks `[1, 3, 8, 10, 12, 13]`, which is 6 graphemes. A UTF-8 round trip of the string was lossless.

Colour emoji: Godot supports CBDT/CBLC bitmap and SVG colour glyphs. COLR/CPAL vector colour fonts (for example the COLRv1 build of Noto Color Emoji, and Segoe UI Emoji on Windows) are reported as unsupported. This comes from a godot-docs change and is not confirmed for 4.7.

## Decision

Keep UTF-8 for every file, the database and HTTP payloads. Files are written without a BOM. No encoding change.

The grapheme cluster is the unit of a glyph. Every place that turns a string into glyphs splits it with `TextServer.string_get_character_breaks` and draws each cluster with `Font.draw_string`. Code must not use `draw_char`, `unicode_at` or per-code-point loops for glyph output.

Bundle a font fallback chain so glyph coverage does not depend on the machine. Colour glyphs are a separate, later decision.

## Consequences

- No data migration. The files and the database already hold UTF-8.
- Code changes are needed in the atlas builders, so they split strings by grapheme cluster and draw with shaping.
- Bundled fonts add size. CJK fonts are about 15 to 20 MB per weight, so the CJK font must be subset to the characters the game uses.
- Bundled Noto fonts are licensed under SIL OFL 1.1. The licence text must ship with the game.
- Until fonts are bundled, glyph shapes differ between machines.
- Colour emoji render as silhouettes in the tinted shaders. Keeping their colour needs a colour-atlas path, which is a later decision.
- Wide glyphs (CJK, emoji and some kaomoji parts) are about twice the width of Latin monospace glyphs. Fixed square atlas cells (32 px) must either scale these glyphs down or give them two cells.
- The `god` tool should warn when a value contains characters that no game font can draw. It should count length in grapheme clusters, not code points.
- Python `str` also counts code points. Grapheme handling in Python needs the `regex` module (`\X`) or a similar approach.
- Compatibility renderer cost is unchanged. Atlases are rasterised once per change, not per frame.
- The base surface glyph ramps moved from code into the DB table `glyph_ramp` (task-079). They are already split into grapheme clusters there.

## Observed on this project (2026-11-09, Windows 11, Godot 4.7.2, Compatibility)

- The base glyph ramps (task-079) drawn through `GlyphRampAtlas` (grapheme clusters, `Font.draw_string`, system font fallback) rendered 世, 界, あ, ア, 한, kaomoji parts, ★, ░▒▓ and 💀 / ⚰️ (one cell each) correctly. The seed ramps rendered pixel-identical to the old baked atlas.
- Segoe UI Emoji glyphs rasterised in colour into the atlas (so this system font works through the fallback). The surface shader reads the atlas as a mask, so in the world they are tinted silhouettes.
- Flags (🇭🇺) drew as the letters "HU": Windows' emoji font has no flag glyphs. A bundled emoji font (TASK-081) is needed for flags.
- Swapping the atlas live on a DB reload kept the game at 29 to 30 FPS (30 FPS cap).

## Follow-up

Backlog tasks that track the work (IDs to be added):

- TASK-080: "Grapheme-aware glyph atlases: split strings with TextServer character breaks everywhere"
- TASK-081: "Bundle a font fallback chain for CJK, symbols and emoji glyphs"
- TASK-082: "Colour glyph atlas path for emoji in glyph shaders"
- TASK-083: "god: warn about glyph text that game fonts cannot draw, count graphemes"
