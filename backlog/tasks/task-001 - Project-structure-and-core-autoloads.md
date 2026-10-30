---
id: TASK-001
title: Project structure and core autoloads
status: Done
assignee:
  - '@claude'
created_date: '2026-10-30T15:29:00Z'
updated_date: '2026-10-30T16:00:00Z'
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
- [x] #1 Folder structure matches the project conventions (snake_case files and folders, PascalCase node names).
- [x] #2 A single signal bus autoload named `SignalBus` exists and is the only autoload added in this task.
- [x] #3 No game state is stored in any autoload.
- [x] #4 The project boots headless with `--quit-after` without errors.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Create folder layout per architecture brief. 2. Add SignalBus autoload script (signals only) and register in project.godot. 3. Validate boot.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Folders created (scripts/{core,world,player,rendering,narrator,ui}, resources/{config,narration}, data/maps, shaders, scenes; empty ones hold .gitkeep). scripts/core/signal_bus.gd registered as the only autoload in project.godot [autoload]. SignalBus holds signals only (run_started, run_ended, run_end_requested). Validation: boot 'godot --headless --path . --quit-after 60' prints 0 ERROR lines. Note: --check-only on scripts referencing SignalBus (run_manager.gd) reports 'Identifier not found: SignalBus' because autoloads are not registered in check-only mode; the same script compiles and runs fine in the full boot and in tools/test_run_manager.gd. Visual not verified (headless only).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added the M1 folder layout (scripts/{core,world,player,rendering,narrator,ui}, resources/{config,narration}, data/maps, shaders, scenes) and the single SignalBus autoload (signals only: run_started, run_ended, run_end_requested). Validated: headless boot has zero errors; godot-validator PASS. Note: --check-only reports a false "SignalBus not found" on scripts using the autoload; tool scripts defer work to the first process_frame for the same reason.
<!-- SECTION:FINAL_SUMMARY:END -->
