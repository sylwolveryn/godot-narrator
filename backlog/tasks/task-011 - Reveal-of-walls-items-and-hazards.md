---
id: TASK-011
title: Reveal of walls, items and hazards
status: Done
assignee:
  - '@claude'
created_date: '2026-10-30T15:30:00Z'
updated_date: '2026-10-30T16:40:00Z'
labels:
  - world
  - ux
milestone: m-0
dependencies:
  - TASK-010
  - TASK-009
documentation:
  - docs/game_design.md
priority: medium
type: feature
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The world must be discovered through play, so walls, items and hazards are hidden at start and appear as the character reaches them. This is the main way the game conveys information, so it has to be reliable from the first run.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 At run start, walls, items and hazards are hidden.
- [x] #2 An element becomes visible when the character reaches or is near it, using the reveal distance from an exported var or `.tres` value.
- [x] #3 Revealed elements stay revealed for the rest of the run.
- [x] #4 Revealed map memory persists across runs: areas seen in earlier runs are remembered at the start of a new run, with their display style coming from a resource
- [x] #5 Revealed state is exposed so the save task can persist it
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. RevealConfig resource (radius, memory style, floor visibility).
2. MapLoader builds per-cell revealable visuals (visuals_at).
3. MapReveal node: hides all at run start, shows remembered cells in memory style, reveals radius around player, emits SignalBus.cells_revealed; SaveService merges into PersistentProgress.revealed_cells[map_id].
4. tools/test_reveal.gd + capture script for visual check.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented: RevealConfig (radius 2.0 cells, reveal_floor=false default, memory_desaturation/brightness), MapLoader per-cell visuals (visuals_at), MapReveal node (hides all at run start, memory style for remembered cells, reveal around player, emits SignalBus.cells_revealed), SaveService merges into PersistentProgress.revealed_cells[map_id] (PackedVector2Array) and exposes get_revealed_cells for task-013. Evidence: tools/test_reveal.gd PASS (hidden at start, radius exactness, sticks, persists into run 2 as dimmer/desaturated memory, re-seen becomes normal, no duplicate announcements). Visual check via tools/capture_reveal.gd (debug autopilot, not in boot path): C:/Users/SYLWOL~1/AppData/Local/Temp/claude/E--git-godot-narrator/9bf6ff4a-2b4c-4f5c-8bbc-2621e15c92c1/scratchpad/shots_011b f00000110 (opening: only glyph), f00000240 (walked), f00000300 and f00000360 (run 2 memory).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
MapReveal hides unseen cells and reveals those within RevealConfig.reveal_radius (2 cells, floor hidden by default so the opening reads as "plain nothing"). Revealed cells persist in PersistentProgress.revealed_cells[map_id] via SignalBus.cells_revealed → SaveService (in memory; disk is task-013); remembered cells show dimmed/desaturated until re-seen. Verified by tools/test_reveal.gd and Movie Maker frames using the optional tools/capture_reveal.gd autopilot.
<!-- SECTION:FINAL_SUMMARY:END -->
