---
id: TASK-023
title: Neon palette, glow and depth in the ASCII renderer
status: To Do
assignee: []
created_date: '2026-10-30T17:45:00Z'
labels:
  - rendering
milestone: m-2
dependencies:
  - TASK-022
documentation:
  - docs/visual_direction.md
priority: high
type: feature
ordinal: 26000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The current renderer flattens everything to grey-blue glyphs on black; the moodboard look needs colour, light and depth.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Walls, floor, items, hazards, memory cells, player and narration use the palette from docs/visual_direction.md
- [ ] #2 Bright glyphs glow (bloom or equivalent) without blurring glyph shapes into unreadable blobs
- [ ] #3 Captures before/after are compared side by side in the task notes
- [ ] #4 Frame rate stays at 60 FPS at 1920x1080 on the dev machine
<!-- AC:END -->
