---
id: TASK-013
title: Persistent progress save
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T15:30:00Z'
updated_date: '2026-10-30T16:42:00Z'
labels:
  - save
  - core
milestone: m-0
dependencies:
  - TASK-005
  - TASK-012
documentation:
  - docs/game_design.md
priority: high
type: feature
ordinal: 13000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Progress must survive a death and a restart, so the player is not starting from nothing each time. The save step is also the foundation for every later meta-progression feature.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Progress is written to disk when a run ends.
- [ ] #2 Progress is loaded when the game starts, and the next run uses it.
- [ ] #3 The saved data contains only persistent values, not per-run state.
- [ ] #4 A missing or corrupt save file falls back to a clean start with a logged message and no crash.
- [ ] #5 Persistent data includes: death count, character identity, revealed map memory, and narration progress
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. SaveConfig resource (save_path) ; SaveService loads in _ready (safe pre-scan, CACHE_MODE_IGNORE, is PersistentProgress check, sanitize, fallback+push_warning) and saves atomically on run_ended.
2. PersistentProgress: death_count, heard_beats.
3. Builders; tools/test_save.gd with temp path.
<!-- SECTION:PLAN:END -->
