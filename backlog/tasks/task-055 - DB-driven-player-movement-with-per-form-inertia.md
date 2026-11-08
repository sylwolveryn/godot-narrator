---
id: TASK-055
title: DB-driven player movement with per-form inertia
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T14:01:00Z'
updated_date: '2026-11-08T14:01:00Z'
labels:
  - gameplay
  - database
dependencies: []
priority: medium
type: feature
ordinal: 57000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Movement felt like levitation (instant start and stop) and its numbers were fixed in PlayerConfig. Speed, acceleration and deceleration now come from a DB movement_profile table, can be tuned while the game runs, and change with the entity form: the small single glyph is quick to start and stop, the grown entity is slower to accelerate but reaches a higher top speed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 DB table movement_profile holds max_speed, acceleration and deceleration for default, single and grown
- [x] #2 The player uses the active form's row (fallback: default row, then PlayerConfig) and switches on every form change
- [x] #3 Values edited during play (god window Movement row or upsert_movement_profile) apply without a restart
- [x] #4 Default movement has a light inertia instead of near-instant start/stop
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
movement_profile table + upsert_movement_profile reducer (bumps config_version so games reload). Seeds: default 4.5/14/16, single 4.8/22/24, grown 5.3/8/10 (speed u/s, accel/decel u/s^2; previously 4.5/30/40). Player.apply_movement_profile picks the form's row on entity_form_changed and on every DB reload. God window: Movement row with profile picker, Load and Apply. Verified: movement checks in tools/test_narration_library.gd, all 19 Godot suites, 53 god unit tests, module published and seeded locally. Feel not judged by hand yet.
<!-- SECTION:FINAL_SUMMARY:END -->
