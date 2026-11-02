---
id: DRAFT-002
title: Beat stance retag and content lint
status: Draft
assignee: []
created_date: '2026-11-02T06:43:00Z'
labels:
  - narrator
milestone: m-1
dependencies: []
documentation:
  - docs/game_design.md
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
