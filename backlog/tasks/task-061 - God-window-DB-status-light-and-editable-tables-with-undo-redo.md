---
id: TASK-061
title: 'God window: DB status light and editable tables with undo/redo'
status: To Do
assignee:
  - '@claude'
created_date: '2026-11-08T14:46:00Z'
labels:
  - tools
  - database
dependencies: []
priority: medium
type: feature
ordinal: 63000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Tuning DB values meant typing SQL or reducer calls, and the DB state was only a text label. The god window should show a clear running/stopped light and let the designer edit table cells in place, saved immediately, with undo/redo.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A green / red indicator shows whether the local DB is running
- [ ] #2 Double-clicking a table cell edits it in place; Enter or leaving the cell saves it to the DB at once and the running game reloads
- [ ] #3 Ctrl+Z / Ctrl+Y undo and redo saved cell edits in the DB
- [ ] #4 Key columns, timestamps and values of the wrong type are refused
<!-- AC:END -->
