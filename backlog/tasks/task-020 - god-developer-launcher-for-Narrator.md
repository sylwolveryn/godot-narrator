---
id: TASK-020
title: 'god: developer launcher for Narrator'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T17:45:00Z'
updated_date: '2026-10-30T17:46:00Z'
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
- [ ] #1 god/ contains a runnable Python GUI with a README describing how to launch it
- [ ] #2 Godot ignores the god/ folder
- [ ] #3 All subtasks are Done
<!-- AC:END -->
