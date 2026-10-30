---
id: TASK-012
title: Hazard death
status: To Do
assignee: []
created_date: '2026-10-30T15:30:00Z'
labels:
  - world
  - core
milestone: m-0
dependencies:
  - TASK-011
  - TASK-005
documentation:
  - docs/game_design.md
priority: high
type: feature
ordinal: 12000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The M1 run must end through a hazard, which is the first real loss condition. Death is what triggers saving and restarting, so this task closes the loop of the first run.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 At least one hazard type from the M1 map ends the run when touched.
- [ ] #2 Hazard definitions (type, damage or effect, visuals) are data-driven.
- [ ] #3 Death emits a run-end signal through `SignalBus`.
- [ ] #4 Death does not pause the game, and the next run starts without a menu.
<!-- AC:END -->
