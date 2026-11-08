---
id: TASK-049
title: Move narration events to DB event ids and wire gameplay
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T13:18:00Z'
updated_date: '2026-11-08T13:46:00Z'
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
- [x] #1 All existing beat texts live in narration/event/<EVENT>_EN_GB.json and play as before
- [x] #2 Gameplay emits IDLE_FOR_SHORT/MID/LONG, HIT_WALL, HIT_UNKNOWN, HIT_SPIKES, TRANSFORMED_TO_ONE/MANY and the DEATH events
- [x] #3 Played time, steps, transformations and deaths by cause are sent to the player table
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Event names are now the DB ids (NarrationEvents), beat tables and docs/narration_origin.md updated, beats rebuilt. Texts copied to narration/event/<EVENT>_EN_GB.json (beat text stays as fallback). New gameplay events: IDLE_FOR_SHORT/MID/LONG ladder, HIT_WALL/HIT_UNKNOWN (player contact, cooldown in PlayerConfig), HIT_SPIKES (hazard touch), DEATH fallback, TRANSFORMED_TO_ONE/MANY with fallback to TRANSFORMED (keeps the claim_ai_one user decision). PlayerRecord sends played time/steps/transformations (flushed) and deaths by cause. Verified by test_narrator, test_narration_library and a live run that filled narration.triggered, player_stats and player_death. Language understanding is seeded (EN_GB 100) but nothing in gameplay changes it yet.
<!-- SECTION:FINAL_SUMMARY:END -->
