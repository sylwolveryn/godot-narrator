---
id: TASK-015
title: Retire legacy prototype main scene
status: To Do
assignee: []
created_date: '2026-10-30T15:30:00Z'
labels:
  - core
milestone: m-0
dependencies: []
priority: high
type: chore
ordinal: 15000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The validator found that the current main.tscn is left over from the first experiment. Its embedded Main script calls `$UI/Instructions`, a node that no longer exists, so every headless boot logs a runtime error. The embedded VectorCharacter script also has a garbled tail. Four stray main.tscn*.tmp files sit in the project root. A clean boot is needed so later tasks can rely on the zero-errors boot check.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `godot --headless --path . --quit-after 60` boots with no ERROR lines
- [ ] #2 Stray main.tscn*.tmp files are removed from the project root
- [ ] #3 Any prototype code worth keeping is noted or moved before the scene is replaced; scene changes are made through tools/ scripts or the Godot MCP, not raw text edits
<!-- AC:END -->
