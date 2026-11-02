---
id: TASK-045
title: Alien origin trial via object pushing
status: Done
assignee:
  - '@claude'
created_date: '2026-11-02T06:43:00Z'
updated_date: '2026-11-02T09:22:00Z'
labels:
  - narrator
milestone: m-1
dependencies:
  - TASK-041
  - TASK-019
documentation:
  - docs/game_design.md
priority: medium
ordinal: 40000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Draft from task-016, blocked by task-019 (small-object pushing). Moving a small object with the grown entity disproves the alien claim while armed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 OBJECT_MOVED fires when the grown entity moves a small object while the alien trial is armed
- [x] #2 The alien CLAIM beat is no longer dormant
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. build_origin: alien non-dormant. 2. Monitor: on object_moved with form GROWN, pass alien when active (armed+alive). 3. Tests in test_origin_trials + test_narrator. 4. Docs.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented: build_origin alien trial non-dormant (trial_alien.tres rebuilt, idempotent); OriginTrialMonitor._on_object_moved passes alien (one grown push, armed+alive, once per run; no seconds so trial_scale n/a). Tests: test_origin_trials (grown push passes; unarmed/single/struck do not; one strike per run, refused trial stays armed) PASS; test_narrator (claim_alien_weight plays on item_revealed and arms alien) PASS; all other tests PASS (test_save printed a parse error from the concurrent menu_glyph_view work, still PASS). Boot --quit-after 60: 0 ERROR. docs/architecture.md updated.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The alien trial is live: OriginTrialMonitor listens to SignalBus.object_moved and passes alien when the grown form pushes a stone while the trial is armed and the nature alive (one push, once per run). claim_alien_weight is no longer dormant and arms the trial on item_revealed; broken/recant alien lines can play. Validator PASS (combined with task-043).
<!-- SECTION:FINAL_SUMMARY:END -->
