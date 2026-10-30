---
id: TASK-020.02
title: 'god: progress viewer'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-30T17:45:00Z'
updated_date: '2026-10-30T17:52:00Z'
labels:
  - tools
milestone: m-2
dependencies: []
parent_task_id: TASK-020
priority: medium
type: feature
ordinal: 22000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Playtesting needs a quick look at what the save contains without opening files by hand.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A section lists the progress fields when progress.tres exists (run count, death count, identity glyph, heard beats, and any future scalar fields), excluding revealed_cells
- [x] #2 The section shows a clear empty state when there is no save
- [x] #3 The list refreshes when the file appears, disappears or changes (checked by the same 3-second poll)
- [x] #4 Reading the save never modifies it; malformed files show an error message instead of crashing
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. core.py pure logic (paths, process matching, controller, ui_state, .tres parser) + god.py tkinter GUI with 3s after() poll; 2. tools/dev_reveal_map.gd + test; 3. unittest suite; 4. README, manual real run.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
parse_progress/read_progress in core.py (read-only, hides revealed_cells+script, generic fields). Unit tests cover missing/malformed/binary and unchanged bytes+mtime after read. GUI polls file signature each 3s. Real save parsed OK; GUI smoke-run (auto-close) exits 0.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented in god/ (core.py logic + god.py tkinter GUI); verified by 27 unittest cases, tools/test_dev_reveal_map.gd PASS, a GUI smoke run and a real start/warn/restart/close cycle (user save backed up and restored, md5 identical). See task notes for evidence.
<!-- SECTION:FINAL_SUMMARY:END -->
