---
id: TASK-020.03
title: 'god: reveal map button'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T17:45:00Z'
updated_date: '2026-10-30T17:51:00Z'
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
- [x] #1 Reveal map marks every non-void cell of the M1 map as revealed in the current progress
- [x] #2 The change is written through a headless Godot tool script that uses the game own save code, so the file format stays valid and passes the save loader safety checks
- [x] #3 The button is disabled when there is no save; if the game is running the user is told to restart it to see the change
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. core.py pure logic (paths, process matching, controller, ui_state, .tres parser) + god.py tkinter GUI with 3s after() poll; 2. tools/dev_reveal_map.gd + test; 3. unittest suite; 4. README, manual real run.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
tools/dev_reveal_map.gd uses SaveService+MapLoader; refuses missing/corrupt save. tools/test_dev_reveal_map.gd PASS (temp save, 3 cases). Real run via god on copy of real save: 733 cells written, other fields kept; real save restored byte-identical.
<!-- SECTION:NOTES:END -->
