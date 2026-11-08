---
id: TASK-047
title: 'God window: SpacetimeDB governance buttons'
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T13:18:00Z'
updated_date: '2026-11-08T13:29:00Z'
labels:
  - tools
  - database
dependencies:
  - TASK-046
priority: medium
type: feature
ordinal: 49000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Running and inspecting the database by hand with the spacetime CLI is slow. The god launcher (god/god.py) gets controls so the designer can run the DB and see its data next to the game controls.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Buttons start and stop the local SpacetimeDB server and publish the module
- [x] #2 A table picker plus Read button shows every row of the chosen table in a formatted grid
- [x] #3 A Reload button bumps config_version so a running game reloads its tables
- [x] #4 Unit tests cover the SQL result parsing
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Logic in god/core.py (DbClient over urllib with cached token, parse_sql_response/format_table, DbServer start/stop/publish with injectable side effects); UI in god/god.py Database section with Log tab + one Treeview tab per table (ttk.Notebook). 50 unit tests pass. Live-verified: DbClient read of all tables and reducer calls; DbServer kill external -> start -> stop_own -> start cycle. UI booted with auto-close; buttons not clicked interactively.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
God window Database section: status, Start/Stop DB (confirm before killing a server god did not start), Publish module, Reload game data (bump_config_version), Clear missing, table picker with Read table / Read all into formatted grids. SQL parsing covered by unit tests.
<!-- SECTION:FINAL_SUMMARY:END -->
