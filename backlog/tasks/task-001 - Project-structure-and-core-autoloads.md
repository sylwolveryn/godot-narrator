---
id: TASK-001
title: Project structure and core autoloads
status: To Do
assignee: []
created_date: '2026-10-30T15:29:00Z'
updated_date: '2026-10-30T15:30:00Z'
labels:
  - core
milestone: m-0
dependencies:
  - TASK-015
documentation:
  - docs/game_design.md
priority: high
type: chore
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The project needs a folder layout and a single signal bus so that every later task has a shared place to put code and events. Without it, UI and data layers will start coupling directly, which breaks the signals-up-only rule.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Folder structure matches the project conventions (snake_case files and folders, PascalCase node names).
- [ ] #2 A single signal bus autoload named `SignalBus` exists and is the only autoload added in this task.
- [ ] #3 No game state is stored in any autoload.
- [ ] #4 The project boots headless with `--quit-after` without errors.
<!-- AC:END -->
