---
id: TASK-005
title: Run state manager and restart flow
status: Done
assignee:
  - '@claude'
created_date: '2026-10-30T15:30:00Z'
updated_date: '2026-10-30T16:00:00Z'
labels:
  - core
milestone: m-0
dependencies:
  - TASK-001
documentation:
  - docs/game_design.md
priority: high
type: feature
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Every run needs a single owner of its lifecycle: starting, ending, and starting again. Without it, death and restart logic will be scattered across scenes and the save task will have nothing reliable to read from.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A run state node or resource tracks the current run's state and is the only owner of run lifecycle transitions.
- [x] #2 Ending a run emits a signal through `SignalBus`, and the manager starts a new run in response.
- [x] #3 Restart produces a clean run state with no leftover values from the previous run (verified by a forced run end in a test scene).
- [x] #4 No game state is stored in an autoload.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. RunConfig, RunState, RunManager (Node under Main). 2. SignalBus signals. 3. tools/test_run_manager.gd forced run end test.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
RunManager (scripts/core/run_manager.gd, child of Main) owns phases INTRO/PLAYING/DYING; end_run() or SignalBus.run_end_requested -> emits SignalBus.run_ended; manager's own listener on run_ended restarts after RunConfig.restart_delay by creating a fresh RunState. Per-run data lives only in RunState. No autoload state. tools/test_run_manager.gd: PASS (forced end -> run_ended(test_cause), run_started(1), fresh state with no leaked elapsed/end_cause, repeated ends give one start each). Boot 0 ERROR. Note: first run is not auto-started on boot (phase stays INTRO); the intro task (006) should call start_run(). Visual not verified (headless only).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
RunManager (child of Main) owns INTRO/PLAYING/DYING, creates a fresh RunState each run, ends runs via end_run() or SignalBus.run_end_requested, and restarts after RunConfig.restart_delay. The first run is not auto-started: the intro (task-006) must call start_run(). Validated by tools/test_run_manager.gd PASS and a clean boot.
<!-- SECTION:FINAL_SUMMARY:END -->
