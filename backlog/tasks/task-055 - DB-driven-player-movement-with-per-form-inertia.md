---
id: TASK-055
title: DB-driven player movement with per-form inertia
status: To Do
assignee:
  - '@claude'
created_date: '2026-11-08T14:01:00Z'
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
- [ ] #1 DB table movement_profile holds max_speed, acceleration and deceleration for default, single and grown
- [ ] #2 The player uses the active form's row (fallback: default row, then PlayerConfig) and switches on every form change
- [ ] #3 Values edited during play (god window Movement row or upsert_movement_profile) apply without a restart
- [ ] #4 Default movement has a light inertia instead of near-instant start/stop
<!-- AC:END -->
