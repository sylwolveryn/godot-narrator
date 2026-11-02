---
id: TASK-045
title: Alien origin trial via object pushing
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-02T06:43:00Z'
updated_date: '2026-11-02T09:00:00Z'
labels:
  - narrator
milestone: m-1
dependencies:
  - TASK-041
  - TASK-019
documentation:
  - docs/game_design.md
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Draft from task-016, blocked by task-019 (small-object pushing). Moving a small object with the grown entity disproves the alien claim while armed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 OBJECT_MOVED fires when the grown entity moves a small object while the alien trial is armed
- [ ] #2 The alien CLAIM beat is no longer dormant
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. build_origin: alien non-dormant. 2. Monitor: on object_moved with form GROWN, pass alien when active (armed+alive). 3. Tests in test_origin_trials + test_narrator. 4. Docs.
<!-- SECTION:PLAN:END -->
