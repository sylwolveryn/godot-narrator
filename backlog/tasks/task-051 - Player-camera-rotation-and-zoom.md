---
id: TASK-051
title: Player camera rotation and zoom
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T13:18:00Z'
updated_date: '2026-11-08T13:19:00Z'
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
- [ ] #1 Q/E and right mouse drag rotate the camera around the player
- [ ] #2 Mouse wheel and PgUp/PgDn zoom in and out within configured limits
- [ ] #3 Movement stays camera-relative after rotating
<!-- AC:END -->
