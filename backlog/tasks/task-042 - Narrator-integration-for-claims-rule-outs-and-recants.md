---
id: TASK-042
title: Narrator integration for claims, rule-outs and recants
status: To Do
assignee: []
created_date: '2026-11-02T06:43:00Z'
updated_date: '2026-11-02T07:36:00Z'
labels:
  - narrator
milestone: m-1
dependencies:
  - TASK-039
  - TASK-040
  - TASK-041
  - TASK-044
documentation:
  - docs/game_design.md
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Draft from task-016. The narrator arms trials with CLAIM beats, reacts to strikes and recants, and plays doubt-flagged lines for struck natures.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Hearing a CLAIM beat arms its trial; BROKEN and RECANT beats play on origin_struck / origin_recanted
- [ ] #2 Beats whose supports are all struck play with the doubt flag (part of the glyphs never settle)
- [ ] #3 At the floor, tie-breaking prefers beats supporting both surviving natures
<!-- AC:END -->
