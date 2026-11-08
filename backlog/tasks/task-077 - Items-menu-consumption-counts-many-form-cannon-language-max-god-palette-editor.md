---
id: TASK-077
title: >-
  Items menu, consumption counts, many-form cannon, language max, god palette
  editor
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T21:03:00Z'
updated_date: '2026-11-08T21:13:00Z'
labels:
  - gameplay
  - menu
  - tools
  - db
dependencies: []
priority: medium
type: feature
ordinal: 82000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Count consumed things; an Items menu entry from the first dirt or diamond, announced by a rainbow pulse from the player; many-form cannon doubles its rate and fires 1-6 balls with own/narrator lines; player_language.max top limit; palette editor in god.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Consumed dirt and diamonds are counted per kind in the save (PersistentProgress.consumed) and in the DB (player_consumed)
- [x] #2 The Items menu entry appears with the first dirt eaten or diamond picked up and lists the counts
- [x] #3 While a menu item is new, a rainbow ring of about 0.3 tile pulses from the player every 5 s until the menu shows it
- [x] #4 In the many form, cannon autofire is twice as fast and every shot launches 1-6 balls; first time: own 'Am I the weapon, or am I the solution?' then narrator 'Thousand year question'
- [x] #5 player_language.max caps understanding when >= 0; a value over it is brought down to it
- [x] #6 god opens a palette editor for colour cells: see, add, change, remove, reorder, hex
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Consumable kinds (scripts/core/consumable.gd) on SignalBus.consumed from DirtWalls/EnemyRemains; SaveService counts (old saves migrated from walls_eaten/diamonds); PlayerRecord -> record_consumed (DB player_consumed). MenuItemDef ACTION_ITEMS/requires_consumed/announce_new; MenuController Items list + new-item tracking (seen_menu_items; old saves: known items pre-marked). Pulse: GlyphWorldView + shader pulse_geo/pulse_style (separate from teleport waves), GlyphWorldConfig pulse_*. Cannon: CannonConfig many_*; CannonSystem follows entity_form_changed; event MANY_FIRED_CANNON with OWN + NARRATOR beats. player_language.max via #[default(-1.0)] migration (data kept); reducer clamps; LanguageProgress.cap/apply_limits from tables_loaded. god: palette.py + palette_dialog.py; reseed shapes rows to the DB columns (old seeds without max work). Verified: tools/test_items_menu.gd PASS, all 35 Godot tests PASS (test_narrator/test_save inventories updated), 96 god unittests, real-DB reseed from a max-less snapshot left the DB identical. Not seen on screen: the pulse in a running game and the palette dialog (Tk windows from the shell did not appear).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Items menu entry with consumption counts, rainbow new-item pulse, many-form cannon (2x rate, 1-6 balls, own/narrator lines), player_language.max, god palette editor.
<!-- SECTION:FINAL_SUMMARY:END -->
