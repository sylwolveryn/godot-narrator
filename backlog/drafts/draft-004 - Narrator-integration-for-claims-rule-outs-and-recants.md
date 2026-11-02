---
id: DRAFT-004
title: Narrator integration for claims, rule-outs and recants
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
Draft from task-016. The narrator arms trials with CLAIM beats, reacts to strikes and recants, and plays doubt-flagged lines for struck natures.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Hearing a CLAIM beat arms its trial; BROKEN and RECANT beats play on origin_struck / origin_recanted
- [ ] #2 Beats whose supports are all struck play with the doubt flag (part of the glyphs never settle)
- [ ] #3 At the floor, tie-breaking prefers beats supporting both surviving natures
<!-- AC:END -->
