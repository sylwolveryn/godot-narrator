---
id: TASK-041
title: Origin trial monitor (demonic, ai, angelic)
status: To Do
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
Draft from task-016. Gameplay tests that disprove a narrator claim: survive high erosion and leave corruption (demonic), choose become one and survive 60 s (ai), stand idle 20 s far from light (angelic).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each trial fires origin_trial_passed only while armed and its nature is alive; thresholds from config
- [ ] #2 At most one strike per run, saved immediately
- [ ] #3 A headless test covers one pass and one non-pass case per trial
<!-- AC:END -->
