---
id: TASK-053
title: Brighter player light and line-of-sight discovery
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T13:18:00Z'
updated_date: '2026-11-08T13:46:00Z'
labels:
  - rendering
  - world
dependencies: []
priority: medium
type: enhancement
ordinal: 55000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The world is too dark and the reveal radius too small. The player should see about twice as far, but discovery must not leak through walls or behind big objects.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Player light and reveal radius are about twice the previous values and ambient is brighter
- [x] #2 Cells behind a wall (#) or an item (*) are not discovered; the blocking cell itself is
- [x] #3 Tests cover the line-of-sight reveal
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Reveal radius 2.75 -> 5.5 cells with line of sight (SightLine, 3 rays; walls, items and void block but are seen themselves; RevealConfig.line_of_sight/sight_blockers/sight_spread). Player light radius 7.5 -> 11, intensity 1.7 -> 2.0, ambient 0.46 -> 0.58, softer depth darkening and fog. Verified by new line-of-sight checks in tools/test_reveal.gd and a rendered frame.
<!-- SECTION:FINAL_SUMMARY:END -->
