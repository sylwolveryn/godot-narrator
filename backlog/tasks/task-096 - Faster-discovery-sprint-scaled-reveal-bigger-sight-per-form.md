---
id: TASK-096
title: Faster discovery, sprint-scaled reveal, bigger sight per form
status: To Do
assignee:
  - '@claude'
created_date: '2026-11-09T08:25:00Z'
labels: []
dependencies: []
priority: medium
type: enhancement
ordinal: 101000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Discovery feels slow: the reveal animation of newly seen cells lags behind movement, so after moving and stopping the area only then becomes visible; at sprint speed the lag is even more visible. The smooth discovery look is liked and stays, it just has to be quicker, scale with sprint, and the seen area should be bigger in the one (single) and many (grown) forms.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Base reveal animation timings (reveal duration, per-cell stagger, memory-to-seen) are half of the previous values
- [ ] #2 While sprinting, the reveal timings are divided further by the active sprint speed multiplier
- [ ] #3 Reveal radius and player light radius are 2x in the single (one) form and 3x in the grown (many) form; brain form keeps 1x; the factors live in a config resource
- [ ] #4 Headless tests cover the timing scale and the per-form area scale
<!-- AC:END -->
