---
id: TASK-076
title: 'Enemy remains: diamonds and black holes'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T17:21:00Z'
updated_date: '2026-11-08T18:42:00Z'
labels:
  - gameplay
  - world
  - rendering
dependencies:
  - TASK-075
priority: high
type: feature
ordinal: 78000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Destroying enemies with cannon balls should pay off and change the map: the wall crawler (autofollow) and the wanderer (random) burst into consumable diamonds; the hunter (seeker) collapses into a black hole, a new map object that destroys enemies that move into it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A cannon-ball hit on a crawler or wanderer bursts it into diamonds (count configurable) the player collects by walking over them; collected diamonds are counted in the save
- [ ] #2 A cannon-ball hit on a hunter leaves a black hole on its cell: a new map object with its own ASCII look, also placeable in maps with its own legend char
- [ ] #3 Any enemy that moves into a black hole is destroyed (and leaves its normal remains); the hole's effect on the player is defined and documented
- [ ] #4 Tests cover both remains, collection and black-hole kills
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. EnemyRemains (data layer): diamonds scatter on enemy_destroyed (EnemyDef.diamonds), hunters (EnemyDef.black_hole) form black holes; map char O; pickups -> PersistentProgress.diamonds; reset at run start
2. EnemySystem kills enemies arriving on a black hole (cause black_hole, normal remains)
3. RemainsView (one MultiMesh glyph billboards: glinting diamonds with burst flight, swirling black holes), DiamondSfx synth ting
4. Narration BLACK_HOLE_FORMED / DIAMOND_FOUND world lines (once)
5. tools/test_remains.gd
<!-- SECTION:PLAN:END -->
