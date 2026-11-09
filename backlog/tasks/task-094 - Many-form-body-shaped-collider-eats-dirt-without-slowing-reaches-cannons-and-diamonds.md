---
id: TASK-094
title: >-
  Many form: body-shaped collider, eats dirt without slowing, reaches cannons
  and diamonds
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-09T01:15:00Z'
labels:
  - gameplay
dependencies: []
priority: high
type: bug
ordinal: 99000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Bug report: in the many (grown) form the whole-body collision (task-090) slows the player when it hits consumables like dirt walls, sometimes gets stuck where nothing is visible, and cannot use cannons. Cause: the collider is a circle as wide as the formation (~4.25) though the formation is only ~2.35 deep, dirt is only eaten on head-on contacts with a 25% speed loss each, and interact reach / diamond pickup use only the heart cell.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The grown collider follows the formation's shape (wide across the screen, shallow up/down) and turns with the camera
- [ ] #2 Pushing the grown body into dirt eats every dirt cell along its front edge without losing speed
- [ ] #3 The grown body can focus and fire cannons when its edge is next to one, and picks up diamonds it covers
<!-- AC:END -->
