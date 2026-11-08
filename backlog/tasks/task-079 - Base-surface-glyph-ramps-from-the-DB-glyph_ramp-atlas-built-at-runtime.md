---
id: TASK-079
title: Base surface glyph ramps from the DB (glyph_ramp), atlas built at runtime
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T23:16:00Z'
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
- [ ] #1 DB table glyph_ramp (surface, chars) seeded with the current ramps; listed in god, seeds and the game's DB tables
- [ ] #2 The game rasterises the base glyph atlas at runtime from glyph_ramp and swaps it in on every DB reload; the baked PNG is only the offline / first-frame fallback
- [ ] #3 Ramp text is split into grapheme clusters; any count of glyphs is spread over the density columns
- [ ] #4 No glyph ramp is hard-coded in GDScript any more
<!-- AC:END -->
