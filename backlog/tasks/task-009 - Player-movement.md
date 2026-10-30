---
id: TASK-009
title: Player movement
status: To Do
assignee: []
created_date: '2026-10-30T15:30:00Z'
labels:
  - player
  - input
milestone: m-0
dependencies:
  - TASK-008
  - TASK-007
documentation:
  - docs/game_design.md
priority: high
type: feature
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Once the input is discovered, the character must move in the world in a way that feels responsive without a pause or a settings screen. Movement is the first thing the player learns, so it must work from the first input onward.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The character moves in the world using the mapped input.
- [ ] #2 Movement speed and acceleration are exported vars or `.tres` values.
- [ ] #3 Movement stops when input stops.
- [ ] #4 The character stays within the bounds of the M1 map.
<!-- AC:END -->
