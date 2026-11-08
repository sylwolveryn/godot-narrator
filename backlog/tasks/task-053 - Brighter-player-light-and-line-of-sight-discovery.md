---
id: TASK-053
title: Brighter player light and line-of-sight discovery
status: To Do
assignee: []
created_date: '2026-11-08T13:18:00Z'
labels:
  - rendering
  - world
dependencies: []
priority: medium
type: enhancement
ordinal: 55000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The world is too dark and the reveal radius too small. The player should see about twice as far, but discovery must not leak through walls or behind big objects.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Player light and reveal radius are about twice the previous values and ambient is brighter
- [ ] #2 Cells behind a wall (#) or an item (*) are not discovered; the blocking cell itself is
- [ ] #3 Tests cover the line-of-sight reveal
<!-- AC:END -->
