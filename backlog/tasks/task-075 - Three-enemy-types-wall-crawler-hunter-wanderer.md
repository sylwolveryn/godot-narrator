---
id: TASK-075
title: 'Three enemy types: wall crawler, hunter, wanderer'
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T17:10:00Z'
updated_date: '2026-11-08T19:07:00Z'
labels:
  - gameplay
  - world
  - rendering
  - database
dependencies:
  - TASK-073
priority: high
type: feature
ordinal: 77000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
First enemies. Each type moves its own way: the crawler always follows a wall (left-hand or right-hand variant), the hunter follows the player, the wanderer moves randomly. They are destructible by cannon balls through the generic destructible interface.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Map chars: L = crawler following the left wall, R = crawler following the right wall, H = hunter, W = wanderer; each drawn as its own ASCII glyph creature
- [x] #2 Movement styles behave as named on the grid (wall following never loses its wall, hunter paths around obstacles to the player, wanderer picks random free directions)
- [x] #3 Touching the player ends the run (cause per enemy type, death narration event); cannon balls destroy enemies
- [x] #4 Enemy speeds and lethality per type in a DB table with defaults; tests cover each movement rule, contact death and destruction
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. MapLegend enemy_spawns (L R H W) + black_hole_char O; MapLoader records MapData.enemies / black_holes (floor)
2. EnemyDef/EnemyConfig (+ from_tables over DB enemy_def), Rust table + seed + god + seed.json + DbConfig.tables
3. EnemySystem (data layer): grid movement crawler/hunter/wanderer, occupancy, Destructibles kind enemy, contact -> run_end_requested(enemy_<type>), reset at run start
4. EnemyView: one MultiMesh billboard glyph creatures, reveal-aware, idle anim
5. DEATH_BY_ENEMY narration event + beats; main scene wiring
6. tools/test_enemies.gd
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
User 2026-11-08: names used by the user: 'autofollow' = wall crawler (L/R), 'random' = wanderer (W), 'seeker' = hunter (H, follows the player). What each leaves behind when destroyed is TASK-076.

EnemySystem (scripts/world/enemy_system.gd) only writer; EnemyDef/EnemyConfig (resources/config/enemy_config.tres) + DB enemy_def (kind PK: speed, lethal, repath_seconds, search_radius, turn_chance, run_min, run_max, diamonds, black_hole), seed.json + Rust + god. Legend L R H W (MapLegend.enemy_spawns), MapData.enemies. Crawler: left/right-hand rule on the grid (wall beside = side or behind-side blocked); open floor -> straight until a wall. Hunter: BFS window 33x33, repath 0.6 s staggered, max 2 searches per physics step, else wanders. Wanderer: runs 3-9, re-roll at junctions 35%. Enemies hold current+next cell; wait 1.2 s then turn. Hazards harmless to enemies. Contact -> hazard_lethal + run_end_requested(enemy_<kind>) -> DEATH_BY_ENEMY (3 beats). Destructibles kind enemy. EnemyView: one MultiMesh (GlyphBillboards, cannon_ball shader), reveal SEEN only, idle bob/wiggle/orbit, destruction puffs. Tests: tools/test_enemies.gd.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
EnemySystem (only writer, restored each run, Destructibles kind enemy). L/R wall followers (left/right-hand rule), H hunter (BFS in a 33x33 window, repath 0.6 s, max 2 searches per step, wanders when out of reach), W wanderer (3-9 cell runs, 35% turn at junctions). Blocked by walls, dirt, props, cannons, objects, other enemies; hazards do not harm them. Contact ends the run (enemy_crawler/hunter/wanderer -> DEATH_BY_ENEMY: 'Bitten', 'Caught. It knew where you would be.', 'They learn your way home. So do I.'). One MultiMesh of glyph creatures (Ж crawler, Ω hunter, & wanderer). DB enemy_def (speed, lethal, diamonds, black_hole, repath, search radius, turn chance, run lengths). m5: ~0.15 ms per step for 26 enemies on the dev PC.
<!-- SECTION:FINAL_SUMMARY:END -->
