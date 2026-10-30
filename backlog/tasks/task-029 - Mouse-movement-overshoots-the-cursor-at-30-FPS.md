---
id: TASK-029
title: Mouse movement overshoots the cursor at 30 FPS
status: To Do
assignee: []
created_date: '2026-10-30T22:27:00Z'
labels:
  - player
  - input
milestone: m-3
dependencies: []
priority: high
type: bug
ordinal: 30000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
With the potato rule (--max-fps 30, physics 60 Hz), tools/test_input_movement.gd fails: "player overshot the cursor (z 14.649, target 14.933)". It passed at uncapped frame rates, so the pointer-move arrival logic likely assumes one physics step per rendered frame. On low-end laptops at 30 FPS the player could jitter or overshoot when walking toward the cursor.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 tools/test_input_movement.gd passes with --max-fps 30 and without a cap
- [ ] #2 Pointer movement stops at the cursor without overshoot or jitter at 30 FPS and 60 FPS
<!-- AC:END -->
