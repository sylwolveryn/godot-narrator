---
id: TASK-020.04
title: 'god: FPS overlay toggle'
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T19:31:00Z'
updated_date: '2026-11-08T19:32:00Z'
labels:
  - tools
  - perf
dependencies: []
parent_task_id: TASK-020
priority: medium
type: feature
ordinal: 79000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Checking performance on the potato target needs FPS, frametime, CPU and GPU time visible in the running game, switched from god without restarting.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 god has an FPS on/off button that shows the current state
- [x] #2 Toggling it shows/hides FPS, frametime, CPU time and GPU time graphs in an already running game within about a second
- [x] #3 When never switched on, the game does not instance the overlay or enable render-time measuring
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Vendor Calinou Debug Menu (asset 1902) into addons/debug_menu; PerfOverlay autoload polls user://dev_flags.cfg; god writes the file; unit tests + real run.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Debug Menu 1.2.0 (commit 9d36ea2, MIT) vendored unmodified; its editor plugin is not enabled, PerfOverlay (scripts/ui/perf_overlay.gd, registered by tools/build_perf_overlay.gd) instances the scene lazily and does nothing headless. god/core.py dev_flags_path/read_perf_overlay/write_perf_overlay (atomic replace). Verified: 74 god unittests OK (4 new); headless boot clean; real windowed run: writing perf=true showed 30 FPS / total / CPU / GPU rows and graphs, perf=false hid them.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added an FPS on/off button to god that toggles the Debug Menu overlay (FPS, frametime, CPU, GPU graphs) live in the running game via user://dev_flags.cfg polled by the new PerfOverlay autoload. Zero cost until first switched on. Verified by unit tests, headless boot and a real run screenshot.
<!-- SECTION:FINAL_SUMMARY:END -->
