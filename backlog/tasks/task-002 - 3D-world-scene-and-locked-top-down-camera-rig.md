---
id: TASK-002
title: 3D world scene and locked top-down camera rig
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T15:29:00Z'
updated_date: '2026-10-30T15:58:00Z'
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
- [ ] #1 A base 3D scene with simple geometry renders in the game window.
- [ ] #2 The camera is locked to a top-down or side view and cannot be rotated by player input.
- [ ] #3 Camera view parameters (position, angle, follow behavior) are exported vars or `.tres` values.
- [ ] #4 The camera rig can be swapped to a tilted view without changing the world scene (verified by configuration, not by unlocking it in M1).
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. CameraViewConfig + CameraRig scripts, WorldConfig. 2. tools/build_resources.gd for top-down and tilted profiles. 3. Extend build_main_scene.gd with World (floor, 2 walls, light), CameraRig, RunManager. 4. Test tool for profile swap.
<!-- SECTION:PLAN:END -->
