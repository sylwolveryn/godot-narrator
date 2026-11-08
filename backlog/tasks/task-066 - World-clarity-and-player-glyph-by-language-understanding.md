---
id: TASK-066
title: World clarity and player glyph by language understanding
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T15:23:00Z'
updated_date: '2026-11-08T15:25:00Z'
labels:
  - rendering
dependencies:
  - TASK-065
priority: medium
type: feature
ordinal: 68000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
At 0% understanding the world looks as it does now (glyph surfaces of floor, hazards and props interleave). As understanding grows the layering becomes clear (floor below, hazards above, props like gargoyles on top) and the player glyph goes from a blunt hollow outline to its full glowing self.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Surface layering order floor < hazards < props; overlap glitch fades with understanding, current look at 0%, clean at 100%
- [ ] #2 Player glyph: hollow, no glow below 6%; glow rises smoothly to today's level at 100%; colours blunt at 0%, slightly more vivid than today at 100%
- [ ] #3 Driven by the selected language's understanding signal; tests and captured frames
<!-- AC:END -->
