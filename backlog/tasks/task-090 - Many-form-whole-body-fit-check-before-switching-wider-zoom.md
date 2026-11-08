---
id: TASK-090
title: 'Many form: whole-body fit check before switching, wider zoom'
status: To Do
assignee: []
created_date: '2026-11-08T23:54:00Z'
labels:
  - gameplay
  - camera
dependencies: []
priority: high
type: feature
ordinal: 95000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Switching to the many form must be refused when the whole grown body does not fit where the player stands (walls, objects). The whole body collides, not only the main glyph. A refusal has narration. The many form allows a further zoom-out. Maps where the many form never fits are not changed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The switch is refused when any cell of the grown footprint is blocked; a narration line explains it
- [ ] #2 In the many form every glyph of the body collides with walls and objects
- [ ] #3 The many form's max zoom distance is larger (config value)
<!-- AC:END -->
