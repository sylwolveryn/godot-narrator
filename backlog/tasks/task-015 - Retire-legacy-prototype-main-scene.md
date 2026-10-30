---
id: TASK-015
title: Retire legacy prototype main scene
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T15:30:00Z'
updated_date: '2026-10-30T15:44:00Z'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Preserve the current (uncommitted) prototype scene as prototype/legacy_main.tscn, with a .gdignore so Godot neither imports nor parses it; add prototype/README.md describing the W/が morph prototype.
2. Add tools/build_main_scene.gd (extends SceneTree) that rebuilds res://main.tscn as an empty Main Node3D root, keeping the scene UID so run/main_scene still resolves.
3. Run the tool headless; delete the four main.tscn*.tmp files.
4. Validate: parse-check the tool script, headless boot with no ERROR lines (godot-validator).
<!-- SECTION:PLAN:END -->
