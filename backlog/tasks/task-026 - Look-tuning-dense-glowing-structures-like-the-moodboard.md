---
id: TASK-026
title: 'Look tuning: dense glowing structures like the moodboard'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T20:36:00Z'
updated_date: '2026-10-30T20:40:00Z'
labels:
  - rendering
milestone: m-2
dependencies:
  - TASK-023
documentation:
  - docs/visual_direction.md
priority: high
type: enhancement
ordinal: 29000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
After the neon renderer (task-023) walls read as faint uniform dot grids and remembered cells are almost invisible: wall luminance sits in the sparse end of the glyph ramp, so structures never become the dense, glowing glyph masses seen in docs/art moodboards. Needs a tuning pass on luminance/ramp/variation, not a new pipeline.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Lit walls near the player render mostly with dense glyphs (upper half of the wall ramp) with visible per-cell variation (edges, height, noise), not a uniform dot grid
- [ ] #2 Remembered cells are clearly readable as remembered (dim, cool) at normal viewing distance without competing with lit cells
- [ ] #3 Side-by-side sheet against the current look is reviewed in task notes; flicker and 60 FPS limits from task-024 still hold
- [ ] #4 docs/visual_direction.md tunables table is updated with any changed defaults
<!-- AC:END -->
