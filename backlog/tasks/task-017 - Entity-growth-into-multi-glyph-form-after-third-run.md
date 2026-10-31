---
id: TASK-017
title: Entity growth into multi-glyph form after third run
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T15:42:00Z'
updated_date: '2026-10-31T11:59:00Z'
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
- [ ] #1 After the configured run count (from a resource) the multi-glyph entity becomes available
- [ ] #2 The entity derives from the saved identity and stays readable under the ASCII shader
- [ ] #3 The unlock persists across sessions
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Persistent: entity_unlocked/entity_form/entity_grow_played in PersistentProgress + sanitizer; SaveService unlock_entity/set_entity_form/mark_entity_grow_played. 2. EntityGrowthConfig (growth_unlock_deaths=3) + EntityFormation text patterns + EntityLayout; EntityProgression node owns unlock/grow-once/form API; SignalBus entity_unlocked, entity_grown, entity_form_changed. 3. EntityGlyphView: 2nd MultiMesh + glyph_entity.gdshader (Spike B morph in vertex shader, erosion, death burst); PlayerGlyphView drives it, heart is instance 0. 4. Tests, captures 1366/1920, perf, docs.
<!-- SECTION:PLAN:END -->
