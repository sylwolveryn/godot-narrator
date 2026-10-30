---
id: TASK-011
title: Reveal of walls, items and hazards
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T15:30:00Z'
updated_date: '2026-10-30T16:26:00Z'
labels:
  - world
  - ux
milestone: m-0
dependencies:
  - TASK-010
  - TASK-009
documentation:
  - docs/game_design.md
priority: medium
type: feature
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The world must be discovered through play, so walls, items and hazards are hidden at start and appear as the character reaches them. This is the main way the game conveys information, so it has to be reliable from the first run.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 At run start, walls, items and hazards are hidden.
- [ ] #2 An element becomes visible when the character reaches or is near it, using the reveal distance from an exported var or `.tres` value.
- [ ] #3 Revealed elements stay revealed for the rest of the run.
- [ ] #4 Revealed map memory persists across runs: areas seen in earlier runs are remembered at the start of a new run, with their display style coming from a resource
- [ ] #5 Revealed state is exposed so the save task can persist it
<!-- AC:END -->
