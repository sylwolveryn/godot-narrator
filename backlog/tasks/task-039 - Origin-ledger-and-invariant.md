---
id: TASK-039
title: Origin ledger and invariant
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-02T06:43:00Z'
updated_date: '2026-11-02T07:38:00Z'
labels:
  - narrator
milestone: m-1
dependencies: []
documentation:
  - docs/game_design.md
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Draft from task-016 (pending user review of the origin rule-out design). The ledger is the single owner of struck/recanted origin natures and enforces the guarantee that at least 2 of the 4 natures always remain and deeds are never struck.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 OriginHypothesis, OriginTrial and OriginConfig resources exist, built by a tools/ builder; 4 nature and 2 deed .tres load
- [ ] #2 OriginLedger is the only writer of struck_natures; a headless test of 1000 random strike sequences keeps >= 2 natures alive and never strikes a deed
- [ ] #3 A save with 3 struck natures is repaired to 2 (newest strike recanted) with a logged warning
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. OriginHypothesis/OriginTrial/OriginConfig resources + tools/build_origin.gd (4 nature + 2 deed .tres, separate trial .tres, origin_config.tres).
2. PersistentProgress fields (struck_natures, armed_trials, strike_counts, last_strike_run); SaveService type-sanitizes them, adds commit_progress() and progress_loaded.
3. SignalBus origin_* signals; OriginLedger node (sole writer, floor rule, per-run cap, load repair); wire in build_main_scene.
4. tools/test_origin_ledger.gd: 1000 random sequences, repair, persistence round trip.
<!-- SECTION:PLAN:END -->
