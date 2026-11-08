---
id: TASK-089
title: 'Narration for recent features: teleport, enemies, diamonds and more'
status: Done
assignee: []
created_date: '2026-11-08T23:53:00Z'
updated_date: '2026-11-08T23:59:00Z'
labels:
  - narration
dependencies: []
priority: medium
type: feature
ordinal: 94000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Recent features fire no or few narration events: teleport trips, destroyed enemies, consumed diamonds, cannon use, black holes, Items menu. Add the missing events and themed lines.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Events and lines for teleport departure and arrival, enemy destroyed, diamond consumed and the first cannon shot
- [x] #2 Events in NarrationEvents, the DB seed and narration/event JSON; lines in the beat table
- [x] #3 Narration lint passes
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
New events TELEPORT_DEPARTED/ARRIVED (TeleportSystem), ENEMY_DESTROYED (EnemySystem), CANNON_FIRED (single form; MANY_FIRED_CANNON in many), MENU_ITEM_NEW (MenuController, a newly offered item), plus own/narrator layers for DIAMOND_FOUND. Lines in m1_beats.json, text files narration/event/*_EN_GB.json, DB SEED_EVENTS (published + seed_defaults). Events for crafting, form blocked and brain added in the same pass (emitted by their tasks). Narration lint passes; test_narrator (83 beats), test_narration_triggers, cannon/enemies/teleports/items tests PASS.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Teleport, enemy, cannon, diamond and new-menu-item events now narrate, in three voices.
<!-- SECTION:FINAL_SUMMARY:END -->
