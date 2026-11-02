---
id: TASK-040
title: Beat stance retag and content lint
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-02T06:43:00Z'
updated_date: '2026-11-02T07:38:00Z'
labels:
  - narrator
milestone: m-1
dependencies:
  - TASK-039
documentation:
  - docs/game_design.md
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Draft from task-016. Beats need supports/contradicts/role instead of origin_tags so rule-outs can drive narration, plus a lint so content keeps every nature both supported and contradicted.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 NarrationBeat has supports, contradicts and role; all 26 beats migrated per the design; origin_tags removed
- [ ] #2 The builder lint fails if a nature lacks a supporting or contradicting beat, or a beat lists a hypothesis in both
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. NarrationBeat: supports/contradicts/role, drop origin_tags.
2. Migrate 26 beats in m1_beats.json per design section 5.
3. NarrationLint class (scripts/narrator) run by tools/build_narration.gd; contradiction rule is a WARNING until json lint.strict_contradiction=true (switched on in task-042/044).
4. Update test_narrator.gd, docs/architecture.md.
<!-- SECTION:PLAN:END -->
