---
id: TASK-039
title: Origin ledger and invariant
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-02T06:43:00Z'
updated_date: '2026-11-02T07:38:00Z'
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
Draft from task-016 (pending user review of the origin rule-out design). The ledger is the single owner of struck/recanted origin natures and enforces the guarantee that at least 2 of the 4 natures always remain and deeds are never struck.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 OriginHypothesis, OriginTrial and OriginConfig resources exist, built by a tools/ builder; 4 nature and 2 deed .tres load
- [ ] #2 OriginLedger is the only writer of struck_natures; a headless test of 1000 random strike sequences keeps >= 2 natures alive and never strikes a deed
- [ ] #3 A save with 3 struck natures is repaired to 2 (newest strike recanted) with a logged warning
<!-- AC:END -->
