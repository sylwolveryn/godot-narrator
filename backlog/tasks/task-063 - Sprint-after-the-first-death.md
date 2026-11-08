---
id: TASK-063
title: Sprint after the first death
status: To Do
assignee:
  - '@claude'
created_date: '2026-11-08T15:03:00Z'
labels:
  - gameplay
  - database
dependencies:
  - TASK-062
priority: high
type: feature
ordinal: 65000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
After the first death the character remembers it can run. Holding Left Shift doubles acceleration, raises top speed and makes the stop slippery. Values per movement profile in the DB.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Sprint (Left Shift / gamepad) works once the player has died at least once (configurable)
- [ ] #2 Sprinting doubles acceleration, raises top speed; stopping after a sprint glides (lower deceleration)
- [ ] #3 Multipliers live in DB movement_profile (with defaults) and PlayerConfig fallback
- [ ] #4 First move of a run with sprint available fires SPRINT_UNLOCKED: World 'Slow', Own 'I Remember now, I am, I was alive. I was moving', Narrator 'Did you?'
<!-- AC:END -->
