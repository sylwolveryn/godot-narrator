---
id: TASK-097
title: 'god: new game mod - all forms unlocked'
status: Done
assignee:
  - '@claude'
created_date: '2026-11-09T08:25:00Z'
updated_date: '2026-11-09T09:10:00Z'
labels: []
dependencies: []
priority: medium
type: feature
ordinal: 102000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Testing the forms needs many runs (deaths, a fully discovered map, teleports) before one, many and brain can be switched. The god launcher's New game with mods should start a game where every form is available. It is a save-only tweak of the fresh game, never a DB change.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The New game with mods dialog has an All forms mod (on/off)
- [x] #2 With it on, the fresh save has the many (grown) and brain forms unlocked plus the menu, so single, grown and brain can be switched
- [x] #3 No DB table is changed
- [x] #4 god Python tests and a headless Godot test cover the mod
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. tools/dev_new_game.gd --all_forms=1 sets entity_unlocked, brain_unlocked, menu_unlocked.
2. god/mods.py: All forms mod (flag, save target, on by default); summary handles field-less mods.
3. Tests: god test_mods, tools/test_all_forms_mod.gd (tool + main scene).
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
god New game with mods has an All forms mod (on by default): dev_new_game.gd --all_forms=1 unlocks the many and brain forms and the menu in the fresh save. Save-only, no DB change. Verified: god unittest (114 OK) and tools/test_all_forms_mod.gd.
<!-- SECTION:FINAL_SUMMARY:END -->
