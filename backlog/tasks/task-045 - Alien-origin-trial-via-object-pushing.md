---
id: TASK-045
title: Alien origin trial via object pushing
status: To Do
assignee: []
created_date: '2026-11-02T06:43:00Z'
updated_date: '2026-11-02T07:36:00Z'
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
