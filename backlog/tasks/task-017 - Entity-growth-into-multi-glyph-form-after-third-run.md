---
id: TASK-017
title: Entity growth into multi-glyph form after third run
status: To Do
assignee: []
created_date: '2026-10-30T15:42:00Z'
labels:
  - player
  - rendering
milestone: m-1
dependencies:
  - TASK-013
documentation:
  - docs/game_design.md
priority: medium
type: feature
ordinal: 17000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The identity persists and evolves: after the third run the single-glyph character extends into a larger multi-character entity. This is the first visible sign of progression and gates new abilities.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 After the configured run count (from a resource) the multi-glyph entity becomes available
- [ ] #2 The entity derives from the saved identity and stays readable under the ASCII shader
- [ ] #3 The unlock persists across sessions
<!-- AC:END -->
