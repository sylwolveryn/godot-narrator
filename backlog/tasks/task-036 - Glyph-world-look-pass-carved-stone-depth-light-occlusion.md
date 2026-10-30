---
id: TASK-036
title: 'Glyph world look pass: carved stone, depth, light occlusion'
status: To Do
assignee: []
created_date: '2026-10-30T22:45:00Z'
labels:
  - rendering
milestone: m-5
dependencies:
  - TASK-031
  - TASK-033
priority: medium
type: enhancement
ordinal: 37000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Spike A weak spots: surfaces read as glowing wireframe blocks rather than carved stone, there are no block edges or rim light, no depth fog, and light passes through walls. A tuning pass against the docs/art moodboards, within the potato budget.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Wall faces read as carved stone, with brighter edges and denser glyphs near light
- [ ] #2 Distance or depth darkening gives the scene depth without hurting readability
- [ ] #3 Light does not visibly leak through walls (cheap approximation is fine)
- [ ] #4 Before/after captures and FPS at 1366x768 with --max-fps 30 are in the notes
<!-- AC:END -->
