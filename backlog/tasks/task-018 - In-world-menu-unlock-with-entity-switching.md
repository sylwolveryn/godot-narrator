---
id: TASK-018
title: In-world menu unlock with entity switching
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T15:42:00Z'
updated_date: '2026-10-31T12:20:00Z'
labels:
  - ux
  - player
milestone: m-1
dependencies:
  - TASK-017
documentation:
  - docs/game_design.md
priority: medium
type: feature
ordinal: 18000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
After three deaths the player gains an in-world menu built by morphing the surroundings (never a pause screen). Its first concrete use is switching between the original single-glyph character and the grown multi-glyph entity.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The menu becomes available after the configured death count (from a resource) and never pauses the game
- [ ] #2 The menu offers switching between the single-glyph and multi-glyph entity when the latter is unlocked
- [ ] #3 The menu is built from in-world ASCII elements, readable per the task-004 overlay decision
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Persist menu_unlocked (PersistentProgress, SaveService.unlock_menu, sanitizer). 2. MenuConfig (menu_unlock_deaths=3, layout, timings) + MenuItemDef resources built by tools/build_menu.gd; InputMap actions menu_toggle/up/down/confirm via build_input_map. 3. MenuController (logic): unlock at death threshold, open/close without pause, selection, confirm -> SignalBus menu_action_requested; EntityProgression applies switch_form. Player stands still while open. 4. MenuGlyphView (presentation): ONE MultiMesh + shaders/glyph_menu.gdshader (Spike B morph from surroundings into framed list, return on close, warm selection glow), floor dim zone in glyph_surface. 5. tools/test_menu.gd, capture_menu.gd, measure with menu open, docs.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
IMPLEMENTED (not committed). New: scripts/core/{menu_config,menu_item_def,menu_controller}.gd, scripts/rendering/menu_glyph_view.gd, shaders/glyph_menu.gdshader, resources/config/menu_config.tres + menu_items/*.tres (tools/build_menu.gd), tools/test_menu.gd, capture_menu.gd, contact_sheet.py. Changed: persistent_progress/save_service (menu_unlocked, sanitized), signal_bus, entity_progression (applies switch_form), player (stands still while open), glyph_surface.gdshader (lift_zone dim), build_input_map (menu_toggle/up/down/confirm), build_main_scene, measure_glyph_world (-- menu), test_save allow-list, docs. EVIDENCE: all tools/test_*.gd PASS (incl. test_menu: locked before 3 deaths, unlock persisted, toggle without pause + physics running + hazards tick, player still while open, nav/confirm switch changes form + entity_form_changed(animate), switch item omitted without entity); boot 0 ERROR. Sheets scratchpad t018_{form,switch,close}_1366.png, t018_{form,switch}_1920.png: formation from surroundings, held with glow, form morph, glyphs returning. PERF GTX1060 30fps menu open: 6.2 draws (+1), GPU 1366x768 0.59ms opening / 0.49 worst; 1920x1061 1.22 / 0.91. Decisions: switch item omitted when entity locked; switching closes the menu; menu closes on run end; mouse hover/click via view->menu_item_pointed signal.
<!-- SECTION:NOTES:END -->
