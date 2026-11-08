---
id: TASK-078
title: 'god: row copy as JSON, live language edits, new game with mods'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T22:37:00Z'
labels:
  - tools
  - db
dependencies: []
priority: medium
type: feature
ordinal: 83000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Multi-row selection with Ctrl/Shift and Ctrl+C JSON copy in god grids; god edits of player_language must reach the running game; a Start new game with mods popup (all languages expert 80%, 10000 dirt, 10000 diamonds).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Rows select with mouse, Ctrl, Shift (also Shift+arrows, Ctrl+A); Ctrl+C copies them as {table: [{column: value}]} JSON in pick order
- [ ] #2 Editing player_language.understanding in god changes the running game's value within a reload
- [ ] #3 New game with mods popup: all languages at 80%, 10000 dirt, 10000 diamonds; choices remembered
<!-- AC:END -->
