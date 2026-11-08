---
id: TASK-047
title: 'God window: SpacetimeDB governance buttons'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T13:18:00Z'
updated_date: '2026-11-08T13:19:00Z'
labels:
  - tools
  - database
dependencies:
  - TASK-046
priority: medium
type: feature
ordinal: 49000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Running and inspecting the database by hand with the spacetime CLI is slow. The god launcher (god/god.py) gets controls so the designer can run the DB and see its data next to the game controls.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Buttons start and stop the local SpacetimeDB server and publish the module
- [ ] #2 A table picker plus Read button shows every row of the chosen table in a formatted grid
- [ ] #3 A Reload button bumps config_version so a running game reloads its tables
- [ ] #4 Unit tests cover the SQL result parsing
<!-- AC:END -->
