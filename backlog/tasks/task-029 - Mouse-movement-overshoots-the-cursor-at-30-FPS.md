---
id: TASK-029
title: Mouse movement overshoots the cursor at 30 FPS
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T22:27:00Z'
updated_date: '2026-10-30T23:52:00Z'
labels:
  - player
  - input
milestone: m-5
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Reproduce at --max-fps 30 and find the true cause of the 'overshoot'.
2. Add per-physics-step arrival clamp in Player so travel never exceeds the remaining distance to the cursor.
3. Make the test deterministic (reachable target, cursor held on a fixed world point) and run it at both 30 FPS and uncapped.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
ROOT CAUSE: not a frame-rate bug in the arrival logic. The test aimed at spawn-area player z+1.0 (target z 14.93) but the wall at row 15 limits the body centre to z 14.65 (15 - body_radius 0.35); the player was simply stopped by the wall (z 14.649 == wall clearance) and the message 'overshot' was misleading (it was an undershoot). Where the player started that phase depends on timer-driven earlier phases, which differ per frame rate, so it passed uncapped. Also the camera follows the player, so a cursor left at a fixed screen point recedes in world space. Fix: test now starts from spawn, targets open floor 1 unit away, re-places the cursor on the same world point each physics frame, and measures worst overshoot past the target, arrival distance and settle wobble. Hardening: Player._limit_to_cursor() clamps velocity each physics step so one step never travels past the cursor (independent of frame rate / residual speed); uses physics delta only. Test runs the full suite with Engine.max_fps 30 then 0.
<!-- SECTION:NOTES:END -->
