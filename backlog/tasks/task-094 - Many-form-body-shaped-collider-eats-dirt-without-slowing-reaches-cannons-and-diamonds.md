---
id: TASK-094
title: >-
  Many form: body-shaped collider, eats dirt without slowing, reaches cannons
  and diamonds
status: Done
assignee:
  - '@claude'
created_date: '2026-11-09T01:15:00Z'
updated_date: '2026-11-09T01:23:00Z'
labels:
  - gameplay
dependencies: []
priority: high
type: bug
ordinal: 99000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Bug report: in the many (grown) form the whole-body collision (task-090) slows the player when it hits consumables like dirt walls, sometimes gets stuck where nothing is visible, and cannot use cannons. Cause: the collider is a circle as wide as the formation (~4.25) though the formation is only ~2.35 deep, dirt is only eaten on head-on contacts with a 25% speed loss each, and interact reach / diamond pickup use only the heart cell.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The grown collider follows the formation's shape (wide across the screen, shallow up/down) and turns with the camera
- [x] #2 Pushing the grown body into dirt eats every dirt cell along its front edge without losing speed
- [x] #3 The grown body can focus and fire cannons when its edge is next to one, and picks up diamonds it covers
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
BodyOutline (scripts/core/body_outline.gd): stadium geometry on XZ. EntityGrowthConfig.body_extents_for: half width x / half depth y of the formation (about 4.25 x 2.35). Player: lying CapsuleShape3D (radius = half depth, height = width) turned to the camera yaw, follows the yaw only when the turned shape has room; _dig_ahead eats dirt in front of the next-step outline (PlayerConfig.dig_ahead_margin), grown_dig_speed_keep 1.0; contact eating accepts any forward-facing dirt contact in the grown form. EntityProgression.fits tests the same capsule. Interactables.player_reaches: grown outline within InteractConfig.body_reach of the footprint (CannonSystem turning uses it too). EnemyRemains: grown body collects diamonds its outline covers. test_many_form_contacts PASS (fails without the dig-ahead: 1.64 of 6.19 travelled); test_many_form, dirt, cannon, interact, entity_growth, pushing, menu, remains, input_movement, brain, enemies, items_menu, large_objects, hazards PASS; boot clean. Not checked in a windowed run.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The many form collides as a lying capsule of its formation (no more invisible blocking above/below), digs through dirt at full speed by eating its whole front ahead of contact, reaches cannons (focus, fire, turn) and picks up diamonds with its outline.
<!-- SECTION:FINAL_SUMMARY:END -->
