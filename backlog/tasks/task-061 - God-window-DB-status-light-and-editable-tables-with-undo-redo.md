---
id: TASK-061
title: 'God window: DB status light and editable tables with undo/redo'
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T14:46:00Z'
updated_date: '2026-11-08T14:46:00Z'
labels:
  - tools
  - database
dependencies: []
priority: medium
type: feature
ordinal: 63000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Tuning DB values meant typing SQL or reducer calls, and the DB state was only a text label. The god window should show a clear running/stopped light and let the designer edit table cells in place, saved immediately, with undo/redo.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A green / red indicator shows whether the local DB is running
- [x] #2 Double-clicking a table cell edits it in place; Enter or leaving the cell saves it to the DB at once and the running game reloads
- [x] #3 Ctrl+Z / Ctrl+Y undo and redo saved cell edits in the DB
- [x] #4 Key columns, timestamps and values of the wrong type are refused
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Canvas dot next to the DB status (green #2ecc71 / red / grey). Grid cells edit in place (ttk.Entry over the cell): Enter/focus-out saves via SQL UPDATE with the owner token from 'spacetime login show --token' (anonymous identities may not run DML), then bump_config_version; Escape cancels. EditHistory gives Ctrl+Z / Ctrl+Y (and Ctrl+Shift+Z), failed undo/redo goes back on its stack, ignored while another text field has focus. Logic in god/core.py (sql_literal, update_sql, CellEdit, EditHistory, parse_cli_token, indicator_color) with 6 new unit tests (67 total pass). Verified live against the local DB by driving the real window: edit 6.0 -> 8.5 saved and config_version bumped, Escape left it, bad number refused, undo/redo/undo restored, key column refused, indicator green. Test edits were reverted.
<!-- SECTION:FINAL_SUMMARY:END -->
