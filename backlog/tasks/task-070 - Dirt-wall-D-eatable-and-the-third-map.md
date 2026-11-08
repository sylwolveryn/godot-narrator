---
id: TASK-070
title: Dirt wall D (eatable) and the third map
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T16:44:00Z'
updated_date: '2026-11-08T16:57:00Z'
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
- [ ] #1 D cells block like walls until the player moves into them; then they crumble (short animation + crunchy sound) and become walkable floor; light, sight and collision update
- [ ] #2 World line 'Crumble, dust, destroyed' the first time ever; narrator line every random 100-200 eaten walls, one of the 5 variants at random
- [ ] #3 data/maps/m3_dirt.txt: normal # walls outside, lots of D with tunnels, fully revealed and no fog via map_settings
- [ ] #4 Eaten count persists in the save; tests cover eating, narration triggers and the map
<!-- AC:END -->
