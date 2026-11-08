---
id: TASK-020.06
title: 'god: save DB to seed and reseed, with 3 seed versions'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T20:18:00Z'
labels:
  - tools
  - db
dependencies: []
parent_task_id: TASK-020
priority: medium
type: feature
ordinal: 81000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Tuning done in the DB should be kept in data/db/seed.json, restorable into the DB, with the last versions kept to go back.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Save DB to seed rotates old <- previous <- current and writes the DB state as current; disabled while the DB equals the current seed
- [ ] #2 Reseed DB loads the version chosen in the Seed box (current / previous / old, only existing files) into the DB
- [ ] #3 Gameplay counters are neither compared nor overwritten
<!-- AC:END -->
