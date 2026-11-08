---
id: TASK-020.05
title: 'god: Reveal map works live on the map in play'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T19:57:00Z'
labels:
  - tools
  - world
dependencies: []
parent_task_id: TASK-020
priority: medium
type: bug
ordinal: 80000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Reveal map only edited the M1 entry of the save with a headless tool, so other maps were never revealed, and a running game overwrote the change with its in-memory progress.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 With the game running, Reveal map reveals the map currently in play at once, without a restart, and the cells are saved
- [ ] #2 Without a running game, Reveal map reveals the map chosen in god's Map box in the save, keeping other maps' progress
<!-- AC:END -->
