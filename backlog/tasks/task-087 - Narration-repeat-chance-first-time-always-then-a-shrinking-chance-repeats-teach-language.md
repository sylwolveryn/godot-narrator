---
id: TASK-087
title: >-
  Narration repeat chance: first time always, then a shrinking chance; repeats
  teach language
status: Done
assignee: []
created_date: '2026-11-08T23:53:00Z'
updated_date: '2026-11-09T00:31:00Z'
labels:
  - narration
dependencies: []
priority: high
type: feature
ordinal: 92000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A trigger's line plays the first time always, even when it has to wait in the queue. Later firings of the same trigger play with a shrinking chance: 80, 60, 50, 35, 20, 12, 6, 3, 3, 3, 3, 3, 2, 2, 2, 2, 2, then 1 % forever. Hearing a line again gives the selected language 1 to 3 %.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A line never heard is guaranteed to play once its turn comes (never dropped from the queue)
- [x] #2 Repeat chance follows the ladder by how many times the line was heard, minimum 1 %; the ladder is data, not code
- [x] #3 Every repeat adds 1 to 3 % (random) to the selected language, within its cap
- [x] #4 Origin claim / broken / recant lines keep their once-only rules
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Narrator: is_repeatable (EVENT + STORY), is_guaranteed (never heard), hearings() (session over saved beat_counts, older heard_beats = 1). Fresh lines (origin or never heard) rank before repeats, least heard first. _offer rolls NarratorConfig.repeat_chance(hearings) (ladder 80..2 %, min 1 %). Guaranteed lines never get dropped: TTL, a higher class or losing the frame moves them to the _waiting FIFO (replaces _parked), which refills the queue during a run; kept across run end. _start counts every story line (SaveService beat_counts) and emits SignalBus.beat_repeated for a repeat; LanguageProgress adds a random 1..3 % (LanguageConfig.repeat_percent_min/max). Tests: test_narrator expectations updated to the new rules (origin rig keeps repeat chance 0), test_narration_triggers checks ladder values, the roll rate (~20 % at 5 hearings) and the 1..3 % gain; save, language, origin tests PASS.

Fix (after commit 454c146): a never-heard line that lost to an equal-class queued line was still dropped; it now waits. Found by test_dirt (first WALL_EATEN world line).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Narration lines play the first time for sure and then repeat on a shrinking chance ladder; every repeat teaches 1-3 % language.
<!-- SECTION:FINAL_SUMMARY:END -->
