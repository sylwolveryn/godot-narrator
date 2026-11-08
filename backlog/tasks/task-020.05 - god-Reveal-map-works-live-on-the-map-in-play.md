---
id: TASK-020.05
title: 'god: Reveal map works live on the map in play'
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T19:57:00Z'
updated_date: '2026-11-08T19:57:00Z'
labels:
  - tools
  - world
dependencies: []
parent_task_id: TASK-020
priority: medium
type: bug
ordinal: 80000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Reveal map only edited the M1 entry of the save with a headless tool, so other maps were never revealed, and a running game overwrote the change with its in-memory progress.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 With the game running, Reveal map reveals the map currently in play at once, without a restart, and the cells are saved
- [x] #2 Without a running game, Reveal map reveals the map chosen in god's Map box in the save, keeping other maps' progress
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
DevBridge autoload (renamed from PerfOverlay; scripts/core/dev_bridge.gd, tools/build_dev_bridge.gd) also reads [commands] reveal_map counter from user://dev_flags.cfg -> SignalBus.dev_reveal_map_requested -> MapReveal.reveal_all(). Counter at start is ignored. god bumps it when the game runs, else runs tools/dev_reveal_map.gd --map=<chosen>. Verified: tools/test_dev_reveal_live.gd PASS (bridge counter + every drawn cell seen and saved), test_dev_reveal_map PASS, tool on m5_shapes save copy keeps m6 entry, 80 god unittests OK, headless boot clean. Not run in a windowed game: the user's own game held the save.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Reveal map now reveals the map in play live through DevBridge, or the chosen map in the save when no game runs.
<!-- SECTION:FINAL_SUMMARY:END -->
