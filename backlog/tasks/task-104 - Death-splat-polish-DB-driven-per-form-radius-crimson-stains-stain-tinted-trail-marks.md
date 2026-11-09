---
id: TASK-104
title: >-
  Death splat polish: DB-driven per-form radius, crimson stains, stain-tinted
  trail marks
status: To Do
assignee: []
created_date: '2026-11-09T11:10:00Z'
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
- [ ] #1 Splat radius range (min/max tiles) is read from the DB per form, with a default row; seeded values: default 2-4, brain 4-6, many 4-8; each death picks a radius in its form range
- [ ] #2 Radius range is editable in god and picked up without code changes; DeathMarksConfig no longer holds the authoritative radius
- [ ] #3 Death stains render as a clearly visible crimson on floor and walls (verified on a captured screenshot)
- [ ] #4 While the player stands on a stained cell the ink trail turns crimson, and stays crimson for 3 s after leaving the last stained cell (duration a config/DB value, not a magic number)
- [ ] #5 While the trail is crimson it leaves crimson stain marks on the floor cells it passes
- [ ] #6 Entering a black hole turns the trail dark purple with the same 3 s linger, and it leaves dark purple marks on the floor
- [ ] #7 Trail marks (crimson and dark purple) persist across deaths and runs on that map and are cleared only when the map is restarted
- [ ] #8 Trail marks do not count toward the stained-tile total that throws the invulnerability item (unless decided otherwise and noted)
- [ ] #9 No FPS regression on the Compatibility renderer: marks reuse the existing per-cell stain texture approach, no per-mark nodes
- [ ] #10 A headless test covers radius range per form, trail tint linger timing and mark persistence/reset
<!-- AC:END -->
