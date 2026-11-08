---
id: TASK-079
title: Base surface glyph ramps from the DB (glyph_ramp), atlas built at runtime
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T23:16:00Z'
updated_date: '2026-11-08T23:21:00Z'
labels:
  - rendering
  - db
dependencies: []
priority: high
type: feature
ordinal: 84000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The wall/floor/spikes/corruption/item/dirt glyph ramps were hard-coded in GlyphAtlasSpec.ROW_GLYPHS and baked into a PNG. They must come from the DB like glyph_anim, so the god tool can change them live.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 DB table glyph_ramp (surface, chars) seeded with the current ramps; listed in god, seeds and the game's DB tables
- [x] #2 The game rasterises the base glyph atlas at runtime from glyph_ramp and swaps it in on every DB reload; the baked PNG is only the offline / first-frame fallback
- [x] #3 Ramp text is split into grapheme clusters; any count of glyphs is spread over the density columns
- [x] #4 No glyph ramp is hard-coded in GDScript any more
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
DB table glyph_ramp (lib.rs SEED_RAMPS, migrated in place), seed.json rows added (only that table), god DB_TABLES / keys / seeds.TABLE_KEYS, DbConfig.tables (db_config.tres saved via ResourceSaver). GlyphRampAtlas: graphemes() via TextServer.string_get_character_breaks, columns_for() spreads any count over 7 columns, draw_cluster() with draw_string + shrink to fit. GlyphAtlasSpec.ROW_GLYPHS removed (SURFACES row order only). GlyphAnimView rebuilds the base atlas on start and every tables_loaded: SubViewport render -> read back -> mipmapped ImageTexture -> glyph_atlas; rows without a DB ramp keep the baked PNG row; skipped headless. tools/build_glyph_atlas.gd bakes the fallback from the seed through the same painter. Verified: test_glyph_ramp PASS; seed render = baked PNG pixel-identical; Unicode ramp image (CJK, kana, kaomoji, emoji); live main scene: runtime atlas applied at start and swapped on a reload with 世界あア💀 walls/floor at 29-30 FPS; related tests and 102 god tests PASS.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Base glyph ramps now come from the DB table glyph_ramp, are split into grapheme clusters and rasterised at runtime; the PNG is only the fallback.
<!-- SECTION:FINAL_SUMMARY:END -->
