---
id: TASK-032
title: Reveal and memory on glyph surfaces
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T22:45:00Z'
updated_date: '2026-10-31T09:16:00Z'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Shader: per-glyph materialise during reveal fade, memory look (cool tint, sparser, floor density, reduced glow). 2. RevealConfig: radius 2.75, slower smoothstep fade; remove per-frame array alloc; cells_seen signal so static lights re-pick. 3. Static lights only for cells seen this run. 4. Extend tools/test_reveal.gd (fade no-flicker, memory->live smooth). 5. Capture tool + sheets at 1366/1080, measure perf, docs.
<!-- SECTION:PLAN:END -->
