---
id: TASK-063
title: Sprint after the first death
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T15:03:00Z'
updated_date: '2026-11-08T15:22:00Z'
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
- [x] #1 Sprint (Left Shift / gamepad) works once the player has died at least once (configurable)
- [x] #2 Sprinting doubles acceleration, raises top speed; stopping after a sprint glides (lower deceleration)
- [x] #3 Multipliers live in DB movement_profile (with defaults) and PlayerConfig fallback
- [x] #4 First move of a run with sprint available fires SPRINT_UNLOCKED: World 'Slow', Own 'I Remember now, I am, I was alive. I was moving', Narrator 'Did you?'
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
sprint action (Left Shift, pad L3/RB). Unlocked at death_count >= 1. Sprint: top speed x1.5, accel x2; after a sprint decel x0.45 until stopped (glide). DB movement_profile gained sprint_* columns (#[default]) + seed; PlayerConfig fallbacks. First move of a run with sprint fires SPRINT_UNLOCKED -> World 'Slow', Own 'I Remember now, I am, I was alive. I was moving', Narrator 'Did you?'. Measured: normal 4.5 u/s in 0.33 s, stop 0.67; sprint 6.75 u/s in 0.18 s, glide 3.22. Not played by hand.
<!-- SECTION:FINAL_SUMMARY:END -->
