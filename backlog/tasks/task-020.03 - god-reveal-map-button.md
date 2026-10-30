---
id: TASK-020.03
title: 'god: reveal map button'
status: To Do
assignee: []
created_date: '2026-10-30T17:45:00Z'
labels:
  - tools
  - world
milestone: m-2
dependencies: []
parent_task_id: TASK-020
priority: medium
type: feature
ordinal: 23000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Testing late-game reveal and memory visuals should not need walking the whole map first.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Reveal map marks every non-void cell of the M1 map as revealed in the current progress
- [ ] #2 The change is written through a headless Godot tool script that uses the game own save code, so the file format stays valid and passes the save loader safety checks
- [ ] #3 The button is disabled when there is no save; if the game is running the user is told to restart it to see the change
<!-- AC:END -->
