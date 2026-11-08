---
id: TASK-078
title: 'god: row copy as JSON, live language edits, new game with mods'
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T22:37:00Z'
updated_date: '2026-11-08T22:37:00Z'
labels:
  - tools
  - db
dependencies: []
priority: medium
type: feature
ordinal: 83000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Multi-row selection with Ctrl/Shift and Ctrl+C JSON copy in god grids; god edits of player_language must reach the running game; a Start new game with mods popup (all languages expert 80%, 10000 dirt, 10000 diamonds).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Rows select with mouse, Ctrl, Shift (also Shift+arrows, Ctrl+A); Ctrl+C copies them as {table: [{column: value}]} JSON in pick order
- [x] #2 Editing player_language.understanding in god changes the running game's value within a reload
- [x] #3 New game with mods popup: all languages at 80%, 10000 dirt, 10000 diamonds; choices remembered
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Grid: selectmode extended, pick-order tracking, raw values kept current by saved edits (core.cell_value), core.rows_json. Live: GameDatabase.server_loads; LanguageProgress.adopt_db_values on reloads after the startup read, ignoring values the game sent (_sent). language_def.name is not used in game (LanguageConfig.display_names). Mods: god/mods.py + mods_dialog.py, GameController.new_game_with_mods, tools/dev_new_game.gd. Verified: 102 god unittests; real god window: RU_RU+MATRIX copy gives the requested JSON, Shift+Down extends, mods dialog defaults; tool writes 9 languages at 80, 10000 dirt/diamonds; test_items_menu (live adoption, echo ignore, startup ignore) and related Godot tests PASS; boot clean. Not run: the full god -> running game round trip on screen.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Row selection + Ctrl+C JSON copy in god, live player_language edits in the game, New game with mods popup.
<!-- SECTION:FINAL_SUMMARY:END -->
