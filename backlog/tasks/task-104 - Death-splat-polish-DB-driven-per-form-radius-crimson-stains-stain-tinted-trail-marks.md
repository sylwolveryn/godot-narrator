---
id: TASK-104
title: >-
  Death splat polish: DB-driven per-form radius, crimson stains, stain-tinted
  trail marks
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-09T11:10:00Z'
updated_date: '2026-11-09T13:05:00Z'
labels:
  - gameplay
  - rendering
  - db
dependencies:
  - TASK-093
priority: medium
ordinal: 110000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Follow-up to TASK-093 (death stains / "splat"). Playtesting found the splat works but needs polish. The splat radius is currently a single fixed value (`DeathMarksConfig.stain_radius` = 1.5 in a .tres), not from the SpacetimeDB data module, so it cannot be tuned per form or live from god. Bigger forms should leave bigger splats: default 2-4 tiles, brain 4-6, many 4-8 (a random radius within the form range per death). The current purple/red stain hue reads poorly on the floor and should be a clearly visible crimson. The player ink trail (TASK-057, colour from the DB `avatar_fx` row) is purple/pink; walking through blood or a black hole should visibly change it and spread marks across the map, making the history of deaths and black holes readable on the floor. Black holes come from enemy remains (TASK-076).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Splat radius range (min/max tiles) is read from the DB per form, with a default row; seeded values: default 2-4, brain 4-6, many 4-8; each death picks a radius in its form range
- [ ] #2 Radius range is editable in god and picked up without code changes; DeathMarksConfig no longer holds the authoritative radius
- [x] #3 Death stains render as a clearly visible crimson on floor and walls (verified on a captured screenshot)
- [x] #4 While the player stands on a stained cell the ink trail turns crimson, and stays crimson for 3 s after leaving the last stained cell (duration a config/DB value, not a magic number)
- [x] #5 While the trail is crimson it leaves crimson stain marks on the floor cells it passes
- [x] #6 Entering a black hole turns the trail dark purple with the same 3 s linger, and it leaves dark purple marks on the floor
- [x] #7 Trail marks (crimson and dark purple) persist across deaths and runs on that map and are cleared only when the map is restarted
- [x] #8 Trail marks do not count toward the stained-tile total that throws the invulnerability item (unless decided otherwise and noted)
- [ ] #9 No FPS regression on the Compatibility renderer: marks reuse the existing per-cell stain texture approach, no per-mark nodes
- [x] #10 A headless test covers radius range per form, trail tint linger timing and mark persistence/reset
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. DB: new table death_splat (profile, radius_min, radius_max) in lib.rs with seed rows default 2-4, grown(many) 4-8, brain 4-6; seed.json, db_config tables, god core/seeds registration, README.
2. DeathMarks: track the active form (entity_form_changed), pick a random radius in the form's range (fallback default row, then DeathMarksConfig defaults) per death.
3. DeathMarks: trail tint state (none/blood/void): standing on a death stain -> blood, on a black hole (EnemyRemains) -> void; lingers trail_tint_linger s after leaving; emits trail_tint_changed. While tinted, each newly entered cell gets a persistent trail mark of that kind (not counted for items), signal trail_marked. Marks live with the stains (per map, per launch).
4. Shader + DeathMarksView: stain texel g = kind (1 blood crimson, 0 void dark purple); crimson/dark purple colours, stronger cell fill so stains read on sparse floors.
5. InkTrailView: per-drop tint (MultiMesh instance colour) so new drops turn crimson/dark purple while existing ones keep their colour.
6. Headless test + screenshot capture; validate boot.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
DB: new table death_splat (profile, radius_min, radius_max) published to the local server and seeded (default 2-4, brain 4-6, grown/many 4-8); bundled in data/db/seed.json, registered in god (core DB_TABLES/DB_PRIMARY_KEYS, seeds TABLE_KEYS) and DbConfig.tables. Single has no row and uses default.
Marks lifetime: trail marks live with the death stains in DeathMarks (per map, whole game launch), so they survive deaths, runs, world resets and map switches; a game restart clears them.
Side effect: a 2-4 splat is 13+ tiles, so with tiles_per_item = 10 the FIRST death now always throws a ⚛ item (before: 9 tiles, none on the first death; after that it was already ~1 per death). test_death_marks, test_respawn_invulnerability and test_entity_growth pin radius_override = 1.5 to keep their 9-tile expectations. Balance left unchanged pending a design call.
Verification: tools/test_death_splat.gd PASS (x3), test_death_marks, test_remains, test_respawn_invulnerability, test_entity_growth, test_cannon, test_enemies, test_hazards, test_input_movement, test_intro_player, test_language_progress, test_menu, test_narrator, test_reveal, test_run_manager, test_save PASS. Visual: tools/capture_death_splat.gd Movie Maker frames show the crimson splat, crimson trail marks along M1 row 11 and dark purple marks after a black hole. FPS on the target iGPU not measured; marks only rewrite texels of the existing stain texture (no nodes).
<!-- SECTION:NOTES:END -->
