---
id: TASK-025
title: Apply morphing to player identity, erosion, death and narration
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T17:45:00Z'
updated_date: '2026-10-30T21:52:00Z'
labels:
  - rendering
  - narrator
  - player
milestone: m-2
dependencies:
  - TASK-024
documentation:
  - docs/visual_direction.md
priority: medium
type: feature
ordinal: 28000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The overlay effects (erosion scramble, death shatter, narration scramble-in) are random character swaps that hurt the eyes. They should use the same true morphing as the world.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Erosion distorts the identity glyph by morphing it towards corrupt shapes instead of swapping random characters
- [ ] #2 Death breaks the glyph apart with morphing fragments that respect the flicker limits
- [ ] #3 Narration text morphs in from and out to abstract shapes letter by letter, legible at full hold
- [ ] #4 Captures of each effect are reviewed and listed in the task notes
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Superseded 2026-10-30: visual direction changed to a glyph-material isometric 3D world + glyph-object morphing (see decision-002). Unfinished work parked on branch parked/sdf-overlay (commit cfcc6ff).
<!-- SECTION:NOTES:END -->
