---
id: TASK-010
title: Handcrafted map loading
status: To Do
assignee: []
created_date: '2026-10-30T15:30:00Z'
labels:
  - world
milestone: m-0
dependencies:
  - TASK-002
documentation:
  - docs/game_design.md
priority: high
type: feature
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The M1 world is one handmade map saved in a file, with no procedural generation. Loading from a file establishes the content pipeline the later world editor will use.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The M1 map is loaded from a file in the project data folder.
- [ ] #2 Map data (walls, items, hazards, spawn point) comes from the file, not from code.
- [ ] #3 Loading the map does not require editing a `.tscn` or `.tres` file as raw text.
- [ ] #4 A map file with a missing or malformed entry produces a logged error and does not crash the game.
<!-- AC:END -->
