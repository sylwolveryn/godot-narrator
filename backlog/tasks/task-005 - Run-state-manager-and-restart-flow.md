---
id: TASK-005
title: Run state manager and restart flow
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T15:30:00Z'
updated_date: '2026-10-30T15:58:00Z'
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
- [ ] #1 A run state node or resource tracks the current run's state and is the only owner of run lifecycle transitions.
- [ ] #2 Ending a run emits a signal through `SignalBus`, and the manager starts a new run in response.
- [ ] #3 Restart produces a clean run state with no leftover values from the previous run (verified by a forced run end in a test scene).
- [ ] #4 No game state is stored in an autoload.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. RunConfig, RunState, RunManager (Node under Main). 2. SignalBus signals. 3. tools/test_run_manager.gd forced run end test.
<!-- SECTION:PLAN:END -->
