---
id: TASK-015
title: Retire legacy prototype main scene
status: Done
assignee:
  - '@claude'
created_date: '2026-10-30T15:30:00Z'
updated_date: '2026-10-30T15:45:00Z'
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
- [x] #1 `godot --headless --path . --quit-after 60` boots with no ERROR lines
- [x] #2 Stray main.tscn*.tmp files are removed from the project root
- [x] #3 Any prototype code worth keeping is noted or moved before the scene is replaced; scene changes are made through tools/ scripts or the Godot MCP, not raw text edits
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Preserve the current (uncommitted) prototype scene as prototype/legacy_main.tscn, with a .gdignore so Godot neither imports nor parses it; add prototype/README.md describing the W/が morph prototype.
2. Add tools/build_main_scene.gd (extends SceneTree) that rebuilds res://main.tscn as an empty Main Node3D root, keeping the scene UID so run/main_scene still resolves.
3. Run the tool headless; delete the four main.tscn*.tmp files.
4. Validate: parse-check the tool script, headless boot with no ERROR lines (godot-validator).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Validation: tools/build_main_scene.gd parse-check clean; `godot --headless --path . --quit-after 60` prints no ERROR/WARNING lines; verbose boot confirms res://main.tscn loads via uid://cd1bjpboqyi2w.
The earlier report that the embedded VectorCharacter script was garbled was wrong: set_form() is a valid function. The real prototype bugs are listed in prototype/README.md.
Leftover: the prototype `transform` input action (T key) is still in project.godot [input]; left for task-008 (input) to replace.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Retired the legacy 2D prototype. The working-tree main.tscn (with embedded scripts) is preserved as prototype/legacy_main.tscn; prototype/.gdignore keeps Godot from parsing it, and prototype/README.md explains what it did and why it was retired. Added tools/build_main_scene.gd, a headless SceneTree tool that rebuilds res://main.tscn as an empty `Main` Node3D while keeping its UID so run/main_scene still resolves. Removed four stray main.tscn*.tmp files. Headless boot now has zero errors. Follow-up: task-002 builds out the 3D scene; the `transform` input action is still in project.godot.
<!-- SECTION:FINAL_SUMMARY:END -->
