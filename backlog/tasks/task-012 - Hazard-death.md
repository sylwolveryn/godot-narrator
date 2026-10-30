---
id: TASK-012
title: Hazard death
status: To Do
assignee: []
created_date: '2026-10-30T15:30:00Z'
updated_date: '2026-10-30T15:42:00Z'
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
- [ ] #1 Hazard definitions (type, damage or effect, visuals) are data-driven.
- [ ] #2 Death emits a run-end signal through `SignalBus`.
- [ ] #3 Death does not pause the game, and the next run starts without a menu.
- [ ] #4 Spike tiles end the run when touched
- [ ] #5 Corrupting glyph areas erode the character over time while inside them and end the run when erosion completes; erosion rate and threshold come from a resource
- [ ] #6 Hazard types for M1 are exactly spikes and corrupting glyphs
<!-- AC:END -->
