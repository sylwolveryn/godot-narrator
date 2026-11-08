---
id: TASK-054
title: DB-driven proximity glyph animation
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T13:18:00Z'
updated_date: '2026-11-08T13:46:00Z'
labels:
  - rendering
  - database
dependencies:
  - TASK-046
priority: medium
type: feature
ordinal: 56000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The shimmering floor glyphs are loved, but their characters, colours and intensity are hardcoded. A glyph_anim table makes them editable and ties the intensity to the distance to the player.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Per surface type the DB defines the character cycle, a colour palette, near/far intensity, radius and speeds
- [x] #2 Characters cycle and colours blend smoothly, more (or less, per config) intense near the player
- [ ] #3 Reloading from the god tool applies new values without restarting the game
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
GlyphAnimView reads the glyph_anim table, rasterises each surface's characters into a small SubViewport atlas and feeds per-type intensity (near/far over radius), speeds and palette into glyph_surface.gdshader, which swaps a hashed share of live glyphs to cycling characters with smoothly blended palette colours. Rows come from GameDatabase.tables_loaded, so a god-tool reload re-applies them. Verified: palette parsing test, rendered frame. Not verified live: a reload from the god window while the game runs (AC3 left open).
<!-- SECTION:FINAL_SUMMARY:END -->
