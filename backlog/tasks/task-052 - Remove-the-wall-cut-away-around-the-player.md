---
id: TASK-052
title: Remove the wall cut-away around the player
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T13:18:00Z'
updated_date: '2026-11-08T13:19:00Z'
labels:
  - rendering
dependencies:
  - TASK-051
priority: low
type: chore
ordinal: 54000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The cut-away that dissolves walls between camera and player looks odd; with camera rotation and zoom the player can find the avatar themselves.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 No surface dissolves near the player any more
- [ ] #2 Cut-away config and shader code are gone
<!-- AC:END -->
