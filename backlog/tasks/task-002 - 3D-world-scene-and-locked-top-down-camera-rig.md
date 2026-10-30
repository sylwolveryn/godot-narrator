---
id: TASK-002
title: 3D world scene and locked top-down camera rig
status: Done
assignee:
  - '@claude'
created_date: '2026-10-30T15:29:00Z'
updated_date: '2026-10-30T16:00:00Z'
labels:
  - rendering
  - world
milestone: m-0
dependencies:
  - TASK-001
documentation:
  - docs/game_design.md
priority: high
type: feature
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The world must be a real 3D scene, but the camera must start locked to a 2D top-down or side view so the game reads as 2D at first. A camera rig gives later tasks a single place to change the view.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A base 3D scene with simple geometry renders in the game window.
- [x] #2 The camera is locked to a top-down or side view and cannot be rotated by player input.
- [x] #3 Camera view parameters (position, angle, follow behavior) are exported vars or `.tres` values.
- [x] #4 The camera rig can be swapped to a tilted view without changing the world scene (verified by configuration, not by unlocking it in M1).
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. CameraViewConfig + CameraRig scripts, WorldConfig. 2. tools/build_resources.gd for top-down and tilted profiles. 3. Extend build_main_scene.gd with World (floor, 2 walls, light), CameraRig, RunManager. 4. Test tool for profile swap.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added scripts/rendering/{camera_view_config,camera_rig}.gd, scripts/world/world_config.gd, resources/config/{camera_top_down,camera_tilted,world_config,run_config}.tres via tools/build_resources.gd; main.tscn rebuilt via tools/build_main_scene.gd (UID uid://cd1bjpboqyi2w kept). Rig has no input handling; view driven only by CameraViewConfig (orthographic, size, fov, pitch, distance, follow_smoothing) plus optional follow_target. tools/test_camera_rig.gd prints PASS: top-down look dir (0,-1,0) ortho; apply_view(camera_tilted.tres) gives perspective, look dir (0,-0.82,-0.57), World child count unchanged. Boot has 0 ERROR lines. Visual not verified (headless only): AC #1 left unchecked because actual rendering in window is unconfirmed. Builders must run on first frame (autoloads unavailable in _init).

Visual check (main session): Movie Maker capture `godot --path . --quit-after 20 --write-movie <scratch>/frame.png` shows the floor plane rendered by the locked orthographic top-down camera. Placeholder walls at z=±10 fall outside the vertical view; acceptable as placeholders (map loading replaces them).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Main now contains World (floor plane, placeholder walls, sun), a locked CameraRig driven only by CameraViewConfig (camera_top_down.tres orthographic; camera_tilted.tres perspective, not player-selectable), built by tools/build_main_scene.gd from configs made by tools/build_resources.gd. Validated by tools/test_camera_rig.gd, a clean headless boot, and a Movie Maker frame showing the rendered floor.
<!-- SECTION:FINAL_SUMMARY:END -->
