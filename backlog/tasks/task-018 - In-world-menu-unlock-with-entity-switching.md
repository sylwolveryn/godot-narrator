---
id: TASK-018
title: In-world menu unlock with entity switching
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T15:42:00Z'
updated_date: '2026-10-31T12:06:00Z'
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
