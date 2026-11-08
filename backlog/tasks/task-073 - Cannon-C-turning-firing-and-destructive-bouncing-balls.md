---
id: TASK-073
title: 'Cannon C: turning, firing and destructive bouncing balls'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T16:54:00Z'
updated_date: '2026-11-08T18:12:00Z'
labels:
  - world
  - gameplay
  - rendering
dependencies:
  - TASK-072
priority: high
type: feature
ordinal: 75000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A new map object C that can be small or big (merged like the gargoyle). It always turns away from a player standing next to it, so the player is at its back, and interacting fires ASCII cannon balls forward. Balls destroy destructible things (dirt D, gargoyle fountains, teleports, future enemies) and bounce off indestructible ones (walls, the player).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 C cells merge like G into small / big cannons; the cannon turns smoothly away from an adjacent player
- [ ] #2 Tap interact = 1 ball; holding over 2 s starts autofire whose rate rises smoothly from 1/s to 5/s over 4 s
- [ ] #3 Balls leave in a 30 degree cone in front of the cannon, travel at most 100 tiles, destroy D / gargoyle / teleport on hit and bounce off walls and the player
- [ ] #4 Destructible is a generic interface (future enemies can opt in); cannons appear on a test map; tests cover turning, fire timing, cone, range, destroy and bounce
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Destructibles registry (kind, is_at, destroy callables); DirtWalls, LargeObjects (new writer), TeleportSystem opt in; SignalBus.destructible_destroyed/restored. 2. Cannon LargeObjectDef C + CannonConfig; Cannon (Interactable) + CannonSystem (turn away, fire, cone). 3. CannonBalls pool sim (grid march, destroy/bounce/player bounce, range+fade). 4. CannonView (8-dir art, aim marker, flash), CannonBallView (MultiMesh), CannonBoomSfx. 5. Arena cannons + D patch; tests/test_cannon.gd; docs.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented per plan. Destroyed gargoyles/teleport pads are restored at run start (like dirt). test_large_objects arena expectation now counts only gargoyle placements (arena has cannons). Visual capture checked: cannon facing away, balls in cone, dirt patch and gargoyle destroyed, teleport pad cracked.
<!-- SECTION:NOTES:END -->
