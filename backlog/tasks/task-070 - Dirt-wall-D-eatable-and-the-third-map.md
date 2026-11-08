---
id: TASK-070
title: Dirt wall D (eatable) and the third map
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T16:44:00Z'
updated_date: '2026-11-08T17:25:00Z'
labels:
  - world
  - gameplay
  - narrator
  - rendering
dependencies:
  - TASK-069
priority: high
type: feature
ordinal: 72000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A Boulder Dash style eatable wall: moving into a D cell breaks it down with a crunch, turning it into floor. A third map built around dirt tests it, fully revealed with no fog.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 D cells block like walls until the player moves into them; then they crumble (short animation + crunchy sound) and become walkable floor; light, sight and collision update
- [x] #2 World line 'Crumble, dust, destroyed' the first time ever; narrator line every random 100-200 eaten walls, one of the 5 variants at random
- [x] #3 data/maps/m3_dirt.txt: normal # walls outside, lots of D with tunnels, fully revealed and no fog via map_settings
- [x] #4 Eaten count persists in the save; tests cover eating, narration triggers and the map
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Legend D = MapLegend.DIRT (light blocking, sight blocker, solid in the visibility map).
2. DirtWalls (data, only writer): one entry SignalBus.dirt_destroy_requested(cell, cause) -> destroy(); chunked collision (16x16, one box per run per row); restore at run start; eaten counter + random milestone in the save.
3. Player: contact with dirt asks for the eat, keeps dig_speed_keep of the speed, no HIT_WALL.
4. DirtView: chunk ArrayMeshes (WorldMeshBuilder.build_dirt_chunk) with the glyph-surface material (dirt marker in COLOR.a, atlas row 5 = dirt ramp, dirt palette), crumble pool, dust MultiMesh. DirtCrunchSfx (override file or synthesized).
5. Narration WALL_EATEN / WALLS_DEVOURED (+ random pick among equal beats), DB/seed rows.
6. Map m3_dirt, game_elements.md, tests test_dirt.gd, visual capture.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented per plan. Per-destroy cost measured in tools/test_dirt.gd (debug build, GTX 1060 box): full 16x16 chunk mesh rebuild ~2.4 ms on a 200x200 all-dirt map; whole destroy() on m3 incl. collision chunk, 1-2 chunk meshes, static light re-bake and signals ~3 ms. Destroyed dirt comes back each run (like pushable objects).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
D dirt walls: DirtWalls is the only writer (SignalBus.dirt_destroy_requested -> destroy(cell, cause) -> dirt_destroyed); 16x16 chunked collision and meshes rebuilt per touched chunk (~3 ms per destroy), local light re-bake, sight re-reveal; dirt restored each run. Eating on contact keeps 75% speed, no HIT_WALL. Crumble + dust MultiMeshes, synthesized crunch (override sfx/dirt_crunch.mp3). Narration: WALL_EATEN world line once 'Crumble, dust, destroyed'; WALLS_DEVOURED every random 100-200 eaten, one of 5 narrator variants (random_pick_events). Save: walls_eaten, next_devour_at. Map m3_dirt 40x30. Tests: test_dirt + all 27 suites. Not verified: potato GPU, 200x200 in a running game.
<!-- SECTION:FINAL_SUMMARY:END -->
