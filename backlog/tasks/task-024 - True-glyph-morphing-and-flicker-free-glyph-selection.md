---
id: TASK-024
title: True glyph morphing and flicker-free glyph selection
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T17:45:00Z'
updated_date: '2026-10-30T18:08:00Z'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Ramp morph in post shader: mix(sdf[i], sdf[i+1], smoothstep(band)) driven by continuous L (no popping).
2. Reveal / memory->seen morph via mask fade (easeOutQuart), spike pulse and corruption breathing (slow flow warp, two-glyph SDF blend, <=0.5 Hz).
3. glyph_morph canvas shader + GlyphAtlas available for task-025.
4. Measure flicker: capture N static frames, per-cell glyph/colour change counts (python); morph strip for one cell.
5. Measure 1080p frame time.
<!-- SECTION:PLAN:END -->
