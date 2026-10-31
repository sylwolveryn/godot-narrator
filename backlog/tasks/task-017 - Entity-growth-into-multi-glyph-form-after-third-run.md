---
id: TASK-017
title: Entity growth into multi-glyph form after third run
status: Done
assignee:
  - '@claude'
created_date: '2026-10-30T15:42:00Z'
updated_date: '2026-10-31T12:03:00Z'
labels:
  - player
  - rendering
milestone: m-1
dependencies:
  - TASK-013
documentation:
  - docs/game_design.md
priority: medium
type: feature
ordinal: 17000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The identity persists and evolves: after the third run the single-glyph character extends into a larger multi-character entity. This is the first visible sign of progression and gates new abilities.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 After the configured run count (from a resource) the multi-glyph entity becomes available
- [x] #2 The entity derives from the saved identity and stays readable under the ASCII shader
- [x] #3 The unlock persists across sessions
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Persistent: entity_unlocked/entity_form/entity_grow_played in PersistentProgress + sanitizer; SaveService unlock_entity/set_entity_form/mark_entity_grow_played. 2. EntityGrowthConfig (growth_unlock_deaths=3) + EntityFormation text patterns + EntityLayout; EntityProgression node owns unlock/grow-once/form API; SignalBus entity_unlocked, entity_grown, entity_form_changed. 3. EntityGlyphView: 2nd MultiMesh + glyph_entity.gdshader (Spike B morph in vertex shader, erosion, death burst); PlayerGlyphView drives it, heart is instance 0. 4. Tests, captures 1366/1920, perf, docs.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
IMPLEMENTED (not committed). New: scripts/core/{entity_form,entity_layout,entity_formation,entity_growth_config,entity_progression}.gd, scripts/rendering/entity_glyph_view.gd, shaders/glyph_entity.gdshader, resources/config/{entity_growth_config,formations/*}.tres via tools/build_entity_growth.gd, tools/test_entity_growth.gd, tools/capture_entity_growth.gd. Changed: persistent_progress, save_service (sanitizer), signal_bus, player_glyph_view, build_main_scene (EntityProgression node, main.tscn rebuilt), measure_glyph_world (-- grown), test_save allow-list, docs. Decisions: unlock at death_count>=3 (config); grow moment on first run after unlock, once (persisted flag); body ignores depth test so walls never hide it; heart stays the player glyph. Signals: entity_unlocked, entity_grown (narrator hook, no text added), entity_form_changed(form, animate); API EntityProgression.set_form()/PlayerGlyphView.set_form(). EVIDENCE: all tools/test_*.gd PASS (incl. test_entity_growth); boot 0 ERROR; progress.tres md5 unchanged. Sheets in scratchpad t17_grow_{1366,1920}.png, t17_life_{1366,1920}.png (walk, erosion, death). PERF GTX1060 30fps: 1366x768 single draws 4.2 GPU 0.53ms; grown draws 5.2 (+1) GPU 0.55 opening, 0.69 worst; 1920x1061 grown GPU 1.13 opening / 0.72 worst.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
EntityProgression unlocks the grown form when death_count reaches growth_unlock_deaths (3). The first run after unlock plays a Spike-B-style grow moment (vertex-shader morph: stagger, eased flight with overshoot, spin, scale pop, glyph flip) into one of 3 data-driven formations (20-37 glyphs) chosen deterministically from the identity, heart = identity glyph; grown form is then active and persisted (entity_unlocked, entity_form, entity_grow_played; sanitized on load). Erosion and death apply to the whole body. Signals entity_unlocked / entity_grown / entity_form_changed and set_form() ready for task-018. +1 draw call, negligible GPU. Validator PASS; new tools/test_entity_growth.gd. Open: formation silhouettes are placeholder art for design review.
<!-- SECTION:FINAL_SUMMARY:END -->
