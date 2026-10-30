---
id: TASK-007
title: Player spawn with random ASCII identity
status: To Do
assignee: []
created_date: '2026-10-30T15:30:00Z'
labels:
  - player
  - rendering
milestone: m-0
dependencies:
  - TASK-006
  - TASK-003
  - TASK-002
documentation:
  - docs/game_design.md
priority: high
type: feature
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The player character is the core of the M1 experience and must appear as a random, exotic ASCII-art character in the middle of the screen. The identity is random per run and must still read clearly through the ASCII shader.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A player character spawns at the center of the screen after the intro.
- [ ] #2 The character's ASCII identity is chosen randomly from a data-driven set (resource or exported list).
- [ ] #3 The identity is readable on screen under the ASCII shader at the chosen cell size.
- [ ] #4 The chosen identity is recorded in run state so that it is consistent for the rest of the run.
<!-- AC:END -->
