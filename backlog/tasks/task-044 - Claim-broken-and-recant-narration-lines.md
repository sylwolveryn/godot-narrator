---
id: TASK-044
title: Claim, broken and recant narration lines
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-02T06:43:00Z'
updated_date: '2026-11-02T08:41:00Z'
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
- [ ] #1 Lines added to the narration doc following the tone curve and the no-tutorial rule
- [ ] #2 The beat lint passes with the new beats
- [ ] #3 User approves the text
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add the 14 approved lines as data/narration/origin_beats.json (text from docs/narration_origin.md), loaded by tools/build_narration.gd. 2. Strict contradiction lint on. 3. Test that text/fields equal the doc.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
User approved all 14 lines in docs/narration_origin.md on 2026-11-02, with one change: claim_ai_one triggers on entity_form_changed (form switch) instead of died_corruption. Lines still need to be added to data/narration and the lint switched to strict (done together with task-042).
<!-- SECTION:NOTES:END -->
