---
id: TASK-040
title: Beat stance retag and content lint
status: Done
assignee:
  - '@claude'
created_date: '2026-11-02T06:43:00Z'
updated_date: '2026-11-02T08:11:00Z'
labels:
  - narrator
milestone: m-1
dependencies:
  - TASK-039
documentation:
  - docs/game_design.md
priority: high
ordinal: 45000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Draft from task-016. Beats need supports/contradicts/role instead of origin_tags so rule-outs can drive narration, plus a lint so content keeps every nature both supported and contradicted.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 NarrationBeat has supports, contradicts and role; all 26 beats migrated per the design; origin_tags removed
- [x] #2 The builder lint fails if a nature lacks a supporting or contradicting beat, or a beat lists a hypothesis in both
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. NarrationBeat: supports/contradicts/role, drop origin_tags.
2. Migrate 26 beats in m1_beats.json per design section 5.
3. NarrationLint class (scripts/narrator) run by tools/build_narration.gd; contradiction rule is a WARNING until json lint.strict_contradiction=true (switched on in task-042/044).
4. Update test_narrator.gd, docs/architecture.md.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented: NarrationBeat supports/contradicts/role (origin_tags removed from beat, builder, tests); all 26 beats in m1_beats.json migrated per design section 5 (5 contradicts entries; counts ai 6, demonic 5, alien 4, angelic 4; 'none' -> empty supports); scripts/narrator/narration_lint.gd (NarrationLint) run by tools/build_narration.gd before anything is written.
Lint: errors for unknown id, id in both lists, nature without supporting beat; nature without contradicting beat is an ERROR only when m1_beats.json lint.strict_contradiction=true, otherwise a printed WARNING (currently alien and angelic). Verified: strict=true -> exit 1 with 'nature alien/angelic has no contradicting beat', nothing built; strict=false -> exit 0 with 2 warnings. Strict mode to be switched on in task-042/044 when the content lands.
Tests: tools/test_narrator.gd updated (stance table, counts, expected contradicts, lint pass/fail cases on synthetic tables; no existing check weakened) PASS. tools/test_save.gd field allow-list extended with the 4 new fields. docs/architecture.md updated. Not edited (off limits): docs/narration_m1.md still mentions origin_tags in its intro.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
NarrationBeat now has supports / contradicts / role (origin_tags removed); all 26 beats migrated per the design stance table. tools/build_narration.gd runs NarrationLint: fails on a hypothesis in both lists, missing support or unknown ids; the "every nature needs a contradicting beat" rule is behind lint.strict_contradiction (off until the approved alien/angelic lines land in task-042/044). Validator PASS.
<!-- SECTION:FINAL_SUMMARY:END -->
