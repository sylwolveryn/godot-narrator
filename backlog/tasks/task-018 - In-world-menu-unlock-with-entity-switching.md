---
id: TASK-018
title: In-world menu unlock with entity switching
status: To Do
assignee: []
created_date: '2026-10-30T15:42:00Z'
labels:
  - ux
  - player
milestone: m-1
dependencies:
  - TASK-017
documentation:
  - docs/game_design.md
priority: medium
type: feature
ordinal: 18000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
After three deaths the player gains an in-world menu built by morphing the surroundings (never a pause screen). Its first concrete use is switching between the original single-glyph character and the grown multi-glyph entity.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The menu becomes available after the configured death count (from a resource) and never pauses the game
- [ ] #2 The menu offers switching between the single-glyph and multi-glyph entity when the latter is unlocked
- [ ] #3 The menu is built from in-world ASCII elements, readable per the task-004 overlay decision
<!-- AC:END -->
