---
id: TASK-020.04
title: 'god: FPS overlay toggle'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T19:31:00Z'
labels:
  - tools
  - perf
dependencies: []
parent_task_id: TASK-020
priority: medium
type: feature
ordinal: 79000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Checking performance on the potato target needs FPS, frametime, CPU and GPU time visible in the running game, switched from god without restarting.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 god has an FPS on/off button that shows the current state
- [ ] #2 Toggling it shows/hides FPS, frametime, CPU time and GPU time graphs in an already running game within about a second
- [ ] #3 When never switched on, the game does not instance the overlay or enable render-time measuring
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Vendor Calinou Debug Menu (asset 1902) into addons/debug_menu; PerfOverlay autoload polls user://dev_flags.cfg; god writes the file; unit tests + real run.
<!-- SECTION:PLAN:END -->
