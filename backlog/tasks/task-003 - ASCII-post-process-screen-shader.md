---
id: TASK-003
title: ASCII post-process screen shader
status: To Do
assignee: []
created_date: '2026-10-30T15:30:00Z'
labels:
  - rendering
milestone: m-0
dependencies:
  - TASK-002
documentation:
  - docs/game_design.md
priority: high
type: feature
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The core visual identity is ASCII glyphs. A full-screen post-process shader converts the rendered 3D image into ASCII, and this must work on the world scene before any other visuals are built on top of it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The rendered world appears as ASCII glyphs on screen.
- [ ] #2 Glyph cell size and glyph set are exported vars or `.tres` values.
- [ ] #3 The shader can be enabled and disabled from configuration for debugging.
- [ ] #4 Frame rate stays at the target set in project settings on the development machine for the M1 map.
<!-- AC:END -->
