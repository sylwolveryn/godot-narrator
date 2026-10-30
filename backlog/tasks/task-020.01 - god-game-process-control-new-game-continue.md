---
id: TASK-020.01
title: 'god: game process control (new game / continue)'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T17:45:00Z'
updated_date: '2026-10-30T17:51:00Z'
labels:
  - tools
milestone: m-2
dependencies: []
parent_task_id: TASK-020
priority: high
type: feature
ordinal: 21000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The core of the launcher: one click to start fresh or continue, without stray processes or manual file deletion. The save is at %APPDATA%/Godot/app_userdata/Narrator/progress.tres.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Start new game: closes the running game if any, deletes progress.tres if it exists (no error if missing), then starts the game
- [x] #2 Continue game is disabled while progress.tres does not exist; the app polls existence every 3 seconds and enables the button when it appears
- [x] #3 Continue game when the game is not running: starts it
- [x] #4 Continue game while the game is running: first click shows a warning that the game is already running; a second click closes the game and starts it again
- [x] #5 A running game is detected even if it was not started by god (editor instances are not treated as the game)
- [x] #6 The Godot executable is found on PATH or via a GODOT_BIN override; the project path is resolved relative to the repo
- [ ] #7 Logic (state, file checks, process matching) is covered by unit tests that run without opening a window
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. core.py pure logic (paths, process matching, controller, ui_state, .tres parser) + god.py tkinter GUI with 3s after() poll; 2. tools/dev_reveal_map.gd + test; 3. unittest suite; 4. README, manual real run.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented god/core.py (GameController, is_game, ui_state) and god/god.py. 27 unittests pass (python -m unittest discover -s god/tests). Real run: continue started game, 2nd click warned, 3rd restarted, new_game deleted save and started, close_game left other godot (editor) processes alone.
<!-- SECTION:NOTES:END -->
