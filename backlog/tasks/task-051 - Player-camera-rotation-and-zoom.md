---
id: TASK-051
title: Player camera rotation and zoom
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T13:18:00Z'
updated_date: '2026-11-08T13:46:00Z'
labels:
  - camera
  - input
dependencies: []
priority: medium
type: feature
ordinal: 53000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The camera is locked, so the player cannot look around obstacles. Rotation and zoom also replace the wall cut-away as the way to find a hidden avatar.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Q/E and right mouse drag rotate the camera around the player
- [x] #2 Mouse wheel and PgUp/PgDn zoom in and out within configured limits
- [x] #3 Movement stays camera-relative after rotating
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
CameraRig: Q/E and right-drag rotate yaw, wheel and PgUp/PgDn zoom within config limits, both smoothed. Player keyboard/pad movement uses the live yaw. Right mouse removed from menu_toggle (Tab/Start remain). World mesh now emits -x/-z faces so rotated views stay solid. Verified by tools/test_camera_rig.gd, test_menu.gd and captured frames.
<!-- SECTION:FINAL_SUMMARY:END -->
