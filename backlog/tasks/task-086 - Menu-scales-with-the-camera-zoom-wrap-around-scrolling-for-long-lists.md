---
id: TASK-086
title: Menu scales with the camera zoom; wrap-around scrolling for long lists
status: To Do
assignee: []
created_date: '2026-11-08T23:53:00Z'
labels:
  - menu
  - ui
dependencies: []
priority: high
type: bug
ordinal: 91000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The in-world menu keeps its world size when the camera zooms, so it is too big or too small. It must look the same at every zoom. Lists longer than fit on screen scroll, and moving past the ends wraps around.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The menu keeps the same on-screen size at every camera zoom
- [ ] #2 A list with more items than fit shows a window of rows that scrolls with the selection
- [ ] #3 Up on the first item goes to the last item, down on the last goes to the first, scrolling the window
- [ ] #4 Works for the item list and every sub list (Language, Items, crafting)
<!-- AC:END -->
