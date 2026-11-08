---
id: TASK-049
title: Move narration events to DB event ids and wire gameplay
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T13:18:00Z'
updated_date: '2026-11-08T13:19:00Z'
labels:
  - narrator
  - gameplay
dependencies:
  - TASK-048
priority: high
type: feature
ordinal: 51000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The existing beats use lowercase internal event names. They move to the DB event ids (DEATH_BY_SPIKES, IDLE_FOR_SHORT, HIT_WALL, TRANSFORMED_TO_MANY ...) and their texts move into per-event narration files, and gameplay emits the new events and feeds the player track record.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All existing beat texts live in narration/event/<EVENT>_EN_GB.json and play as before
- [ ] #2 Gameplay emits IDLE_FOR_SHORT/MID/LONG, HIT_WALL, HIT_UNKNOWN, HIT_SPIKES, TRANSFORMED_TO_ONE/MANY and the DEATH events
- [ ] #3 Played time, steps, transformations and deaths by cause are sent to the player table
<!-- AC:END -->
