---
id: TASK-019
title: Small-object pushing for the multi-glyph entity
status: To Do
assignee: []
created_date: '2026-10-30T15:42:00Z'
labels:
  - player
  - world
milestone: m-1
dependencies:
  - TASK-017
documentation:
  - docs/game_design.md
priority: medium
type: feature
ordinal: 19000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The grown entity must feel meaningfully different: it can move small objects, which the single-glyph form cannot do during the first three runs. This opens new routes and puzzles in handcrafted maps.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The multi-glyph entity can push objects marked as small in map data
- [ ] #2 The single-glyph form cannot move those objects
- [ ] #3 Push parameters come from a resource
<!-- AC:END -->
