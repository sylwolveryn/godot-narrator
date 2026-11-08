---
id: TASK-020.06
title: 'god: save DB to seed and reseed, with 3 seed versions'
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T20:18:00Z'
updated_date: '2026-11-08T20:18:00Z'
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
- [x] #1 Save DB to seed rotates old <- previous <- current and writes the DB state as current; disabled while the DB equals the current seed
- [x] #2 Reseed DB loads the version chosen in the Seed box (current / previous / old, only existing files) into the DB
- [x] #3 Gameplay counters are neither compared nor overwritten
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
god/seeds.py (snapshot, canonical compare, rotation with row order kept, multi-row INSERT reseed with backup/restore), UI row in god.py. SpacetimeDB SQL: one statement per request, multi-row INSERT works, explicit narration ids keep the auto_inc sequence usable (checked: next row got 253). Verified: 91 god unittests; real DB reseed from seed.json -> DB == current; GUI cycle (edit DB -> Save enabled -> save -> previous created, Save disabled -> reseed previous -> 'DB = previous seed'). Test files reverted afterwards.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Save DB to seed / Reseed DB / Seed version box in god, keeping current, previous and old seed files.
<!-- SECTION:FINAL_SUMMARY:END -->
