---
id: TASK-038
title: Camera-relative keyboard and gamepad movement in the isometric view
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T23:08:00Z'
updated_date: '2026-10-30T23:52:00Z'
labels:
  - input
  - player
milestone: m-5
dependencies:
  - TASK-031
priority: high
type: bug
ordinal: 39000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Since task-031 the camera is isometric (yaw 45), but keyboard/gamepad movement still uses world axes, so pressing up moves the player diagonally up-right on screen. Mouse movement already follows the camera ray. Players expect up to mean up on screen.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Up/down/left/right on keyboard and the d-pad move the player up/down/left/right on screen; the left stick maps to screen directions too
- [ ] #2 The mapping derives from the active camera view config, not hardcoded angles
- [ ] #3 tools/test_input_movement.gd asserts screen-relative directions (alongside the task-029 overshoot fix)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Player gets exported camera_rig; rotate keyboard/d-pad/stick input by camera_rig.view_config.yaw_degrees (no hardcoded angle).
2. Wire camera_rig in tools/build_main_scene.gd and regenerate main.tscn with the tool.
3. Rewrite tools/test_input_movement.gd direction checks as screen-space assertions via the camera basis.
<!-- SECTION:PLAN:END -->
