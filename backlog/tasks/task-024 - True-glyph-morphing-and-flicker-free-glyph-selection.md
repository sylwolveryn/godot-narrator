---
id: TASK-024
title: True glyph morphing and flicker-free glyph selection
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
ordinal: 27000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Glyph changes are instant swaps between characters, which read as noise. Glyphs must morph continuously from one shape to another, and the per-cell glyph choice must not flicker when the scene barely changes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A glyph change in the world renders as a continuous shape interpolation over a configurable duration (e.g. signed-distance-field blend), not a swap
- [ ] #2 A static scene shows no glyph flicker; small brightness changes do not toggle glyphs back and forth (hysteresis or temporal smoothing)
- [ ] #3 A frame sequence in the task notes shows a single glyph morphing smoothly between two characters
- [ ] #4 Frame rate stays at 60 FPS at 1920x1080 on the dev machine
<!-- AC:END -->
