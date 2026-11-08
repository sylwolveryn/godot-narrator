---
id: TASK-058
title: Merged multi-cell map objects and the gargoyle fountain (G)
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T14:07:00Z'
updated_date: '2026-11-08T14:07:00Z'
labels:
  - world
  - rendering
dependencies: []
priority: high
type: feature
ordinal: 60000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Bigger props should be authored by repeating their character in the map. Adjacent same characters of a mergeable type form one rectangular object scaled to its footprint (GG = twice as wide, GG/GG = twice as big). The gargoyle fountain G is the first such object.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The map legend marks mergeable types; adjacent cells of one type merge into rectangles (non-rectangular groups split into rectangles)
- [ ] #2 G renders as one ASCII-art gargoyle fountain scaled to its footprint, blocks movement and line of sight
- [ ] #3 Tests cover the merging (1x1, 2x1, 2x2, L-shape)
<!-- AC:END -->
