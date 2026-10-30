---
id: TASK-006
title: 'Intro sequence: black screen and abstract wave'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T15:30:00Z'
updated_date: '2026-10-30T16:08:00Z'
labels:
  - ux
  - rendering
milestone: m-0
dependencies:
  - TASK-003
documentation:
  - docs/game_design.md
priority: medium
type: feature
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The first moment of the game sets the mood and shows the ASCII identity before the player does anything. The intro needs to play on a black screen with an abstract wave effect, then hand off to the spawn step.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 On launch the screen is black, then an abstract wave effect plays.
- [ ] #2 The intro ends automatically and hands off to the spawn step without a pause or menu.
- [ ] #3 Intro timings are exported vars or `.tres` values.
- [ ] #4 Input during the intro does not break the sequence.
<!-- AC:END -->
