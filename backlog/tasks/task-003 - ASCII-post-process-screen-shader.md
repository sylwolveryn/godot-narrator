---
id: TASK-003
title: ASCII post-process screen shader
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T15:30:00Z'
updated_date: '2026-10-30T16:01:00Z'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. AsciiConfig resource (cell size, ramp, colors, enabled). 2. ascii_post.gdshader sampling hint_screen_texture per cell + glyph atlas. 3. AsciiPostProcess CanvasLayer(layer 0) rasterises atlas from SystemFont at runtime, sets uniforms. 4. Extend builders. 5. Validate headless + Movie Maker screenshot + fps.
<!-- SECTION:PLAN:END -->
