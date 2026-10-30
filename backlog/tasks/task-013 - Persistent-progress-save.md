---
id: TASK-013
title: Persistent progress save
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T15:30:00Z'
updated_date: '2026-10-30T16:54:00Z'
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
- [x] #1 Progress is written to disk when a run ends.
- [x] #2 Progress is loaded when the game starts, and the next run uses it.
- [x] #3 The saved data contains only persistent values, not per-run state.
- [x] #4 A missing or corrupt save file falls back to a clean start with a logged message and no crash.
- [x] #5 Persistent data includes: death count, character identity, revealed map memory, and narration progress
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. SaveConfig resource (save_path) ; SaveService loads in _ready (safe pre-scan, CACHE_MODE_IGNORE, is PersistentProgress check, sanitize, fallback+push_warning) and saves atomically on run_ended.
2. PersistentProgress: death_count, heard_beats.
3. Builders; tools/test_save.gd with temp path.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented: SaveConfig (save_path, allowed script whitelist), SaveService loads in _ready (before any run) and saves atomically (temp+rename) on run_ended; PersistentProgress gains death_count, heard_beats. Load safety: text pre-scan rejects sub_resources/foreign scripts, ResourceLoader CACHE_MODE_IGNORE, is PersistentProgress check, field sanitizing; missing/corrupt -> fresh + push_warning. Existing tests now use temp save paths (tools/test_support.gd). Evidence: tools/test_save.gd PASS (round trip, only 5 persistent fields, run_ended writes file, load-before-first-run applies identity/memory/counts, missing, garbage, truncated, wrong type, embedded script, foreign script, sanitization, cleanup); all tests PASS; no real user://progress.tres created by tests. Note: save happens on run end only (and when identity is first chosen); quitting mid-run loses that run's new reveals. Truncated file with an intact header makes the engine log an ERROR line before fallback.
<!-- SECTION:NOTES:END -->
