---
id: TASK-075
title: 'Three enemy types: wall crawler, hunter, wanderer'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T17:10:00Z'
updated_date: '2026-11-08T18:55:00Z'
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
- [ ] #1 Map chars: L = crawler following the left wall, R = crawler following the right wall, H = hunter, W = wanderer; each drawn as its own ASCII glyph creature
- [ ] #2 Movement styles behave as named on the grid (wall following never loses its wall, hunter paths around obstacles to the player, wanderer picks random free directions)
- [ ] #3 Touching the player ends the run (cause per enemy type, death narration event); cannon balls destroy enemies
- [ ] #4 Enemy speeds and lethality per type in a DB table with defaults; tests cover each movement rule, contact death and destruction
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
