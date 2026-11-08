---
id: TASK-072
title: Interact control (Space / left click)
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T16:54:00Z'
updated_date: '2026-11-08T17:48:00Z'
labels:
  - input
  - gameplay
dependencies: []
priority: high
type: feature
ordinal: 74000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Objects like the cannon need a generic interact action. Space and left click already mean other things (menu confirm, intro skip, walk to cursor), so interact must take precedence only when an interactable object is in reach.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 InputMap action interact: Space and left mouse button (and a gamepad button)
- [ ] #2 When the player stands next to an interactable, press / hold go to that object and the click does not also walk the player; otherwise Space / click keep their old meaning
- [ ] #3 Interactables register generically (press, hold duration, release) so later objects can reuse it
<!-- AC:END -->
