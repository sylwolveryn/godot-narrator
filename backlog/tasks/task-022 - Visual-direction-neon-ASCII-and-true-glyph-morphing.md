---
id: TASK-022
title: 'Visual direction: neon ASCII and true glyph morphing'
status: To Do
assignee: []
created_date: '2026-10-30T17:45:00Z'
labels:
  - rendering
milestone: m-2
dependencies: []
priority: high
type: docs
ordinal: 25000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Playtest: colours are dull and the glyph changes hurt the eyes; changes are hard swaps, not morphs. The moodboard in docs/art (neon sunset, midnight cavern) shows the target: glowing glyphs, rich per-region colour, density and depth. A short spec is needed before the shader and effects are reworked.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 docs/visual_direction.md defines the palette (per cell type, memory style, hazards, player, narration), glow/bloom, depth cues and motion rules
- [ ] #2 It defines what a morph is (continuous shape interpolation between glyphs, not swaps) and limits on flicker (rate, contrast, area)
- [ ] #3 All values it sets are listed as config-resource tunables
<!-- AC:END -->
