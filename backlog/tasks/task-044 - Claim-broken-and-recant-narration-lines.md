---
id: TASK-044
title: Claim, broken and recant narration lines
status: Done
assignee:
  - '@claude'
created_date: '2026-11-02T06:43:00Z'
updated_date: '2026-11-02T09:00:00Z'
labels:
  - narrator
milestone: m-1
dependencies: []
documentation:
  - docs/game_design.md
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Draft from task-016. About 14 new lines (claim/broken/recant per nature plus contradicting lines for alien and angelic). Story content: user-authored or user-approved.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Lines added to the narration doc following the tone curve and the no-tutorial rule
- [x] #2 The beat lint passes with the new beats
- [x] #3 User approves the text
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add the 14 approved lines as data/narration/origin_beats.json (text from docs/narration_origin.md), loaded by tools/build_narration.gd. 2. Strict contradiction lint on. 3. Test that text/fields equal the doc.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
User approved all 14 lines in docs/narration_origin.md on 2026-11-02, with one change: claim_ai_one triggers on entity_form_changed (form switch) instead of died_corruption. Lines still need to be added to data/narration and the lint switched to strict (done together with task-042).

14 approved lines added as data/narration/origin_beats.json (generated from docs/narration_origin.md; tools/test_narrator.gd compares text and every field against the doc), appended by tools/build_narration.gd. lint.strict_contradiction is true in m1_beats.json; build_narration passes strict (builders idempotent apart from random node unique_ids in main.tscn, pre-existing). Lint gained role rules. AC3 user approval recorded 2026-11-02. Not committed.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The 14 user-approved lines (2026-11-02) are in data/narration/origin_beats.json, text identical to docs/narration_origin.md (verified by test and validator); claim_ai_one triggers on the form switch per the user. Strict contradiction lint is on and passes. Alien lines stay dormant until task-045.
<!-- SECTION:FINAL_SUMMARY:END -->
