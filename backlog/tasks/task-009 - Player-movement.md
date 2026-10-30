---
id: TASK-009
title: Player movement
status: Done
assignee:
  - '@claude'
created_date: '2026-10-30T15:30:00Z'
updated_date: '2026-10-30T16:40:00Z'
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
- [x] #1 The character moves in the world using the mapped input.
- [x] #2 Movement speed and acceleration are exported vars or `.tres` values.
- [x] #3 Movement stops when input stops.
- [x] #4 The character stays within the bounds of the M1 map.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. PlayerConfig movement values (speed/accel/friction/pointer stop distance).
2. Player._physics_process: top-down XZ, FLOATING move_and_slide, gated on PLAYING + discovered scheme; mouse scheme projects cursor onto ground plane.
3. MapLoader adds boundary collision (void-adjacent cells + outer slabs) under a Bounds node.
4. Tests in tools/test_input_movement.gd.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented: Player._physics_process, FLOATING CharacterBody3D, move_toward accel/friction from PlayerConfig (max_speed, acceleration, friction, pointer_*), gated on PLAYING + discovered scheme; mouse scheme projects cursor onto y=0 plane. MapLoader adds Bounds node (void-edge boxes + 4 outer slabs). Evidence: tools/test_input_movement.gd PASS: no move before discovery, first press moves, stops on release, wall collision at z=15-radius, void and map-edge bounds hold, scheme survives restart. Visual: C:/Users/SYLWOL~1/AppData/Local/Temp/claude/E--git-godot-narrator/9bf6ff4a-2b4c-4f5c-8bbc-2621e15c92c1/scratchpad/shots_011b.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Player moves on the XZ plane with move_and_slide only after discovery and only while PLAYING; first press moves immediately; stops on release; walls and void/map-edge bounds block it; mouse scheme walks toward the cursor without overshoot. All values in PlayerConfig. tools/test_input_movement.gd PASS.
<!-- SECTION:FINAL_SUMMARY:END -->
