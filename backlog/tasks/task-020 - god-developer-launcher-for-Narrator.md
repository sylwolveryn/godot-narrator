---
id: TASK-020
title: 'god: developer launcher for Narrator'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T17:45:00Z'
updated_date: '2026-10-30T17:51:00Z'
labels:
  - tools
milestone: m-2
dependencies: []
priority: high
type: feature
ordinal: 20000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Resetting or continuing playtests currently needs shell commands that fail when the save file is missing. A small Python GUI ("god") in the repo should start, reset and inspect the game in one click. Lives in god/ at the repo root, ignored by Godot via .gdignore.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 god/ contains a runnable Python GUI with a README describing how to launch it
- [x] #2 Godot ignores the god/ folder
- [ ] #3 All subtasks are Done
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. core.py pure logic (paths, process matching, controller, ui_state, .tres parser) + god.py tkinter GUI with 3s after() poll; 2. tools/dev_reveal_map.gd + test; 3. unittest suite; 4. README, manual real run.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
god/ with README.md and .gdignore; test_save PASS and boot smoke clean after changes.
<!-- SECTION:NOTES:END -->
