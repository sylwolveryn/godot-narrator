---
id: TASK-059
title: Arena test map
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T14:07:00Z'
updated_date: '2026-11-08T14:29:00Z'
labels:
  - world
dependencies:
  - TASK-058
priority: medium
type: feature
ordinal: 61000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The M1 map is a maze. An open antique arena with scattered obstacles is needed to test the merged objects.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 data/maps/m2_arena.txt: open arena with gargoyles of several footprints, pillars and some hazards/items
- [x] #2 The map loads and plays (headless boot and test)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
data/maps/m2_arena.txt 46x32 octagonal arena: 1x1, 1x2, 2x1, 2x2, 3x2 and an L-shaped gargoyle group, pillars, spikes, corruption pool, 3 items, 4 pushables. Loaded and played in test_large_objects (clean parse, reachability, reveal).
<!-- SECTION:NOTES:END -->
