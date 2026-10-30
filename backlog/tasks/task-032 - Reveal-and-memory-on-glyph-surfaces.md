---
id: TASK-032
title: Reveal and memory on glyph surfaces
status: To Do
assignee: []
created_date: '2026-10-30T22:45:00Z'
labels:
  - rendering
  - world
milestone: m-5
dependencies:
  - TASK-031
priority: high
type: feature
ordinal: 33000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Reveal (hidden until near) and remembered cells from earlier runs were built for the old renderer. They need to work on the new glyph-surface world: unseen cells dark, cells fading in as they are revealed, remembered cells shown in a dim cool style.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 At run start only cells within the reveal radius are visible; revealed cells fade in calmly
- [ ] #2 Remembered cells from earlier runs show in a dim, cool style that is readable but clearly different from lit cells
- [ ] #3 tools/test_reveal.gd passes against the new renderer without weakening its checks
<!-- AC:END -->
