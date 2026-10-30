---
id: TASK-003
title: ASCII post-process screen shader
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T15:30:00Z'
updated_date: '2026-10-30T16:04:00Z'
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
- [x] #1 The rendered world appears as ASCII glyphs on screen.
- [x] #2 Glyph cell size and glyph set are exported vars or `.tres` values.
- [x] #3 The shader can be enabled and disabled from configuration for debugging.
- [x] #4 Frame rate stays at the target set in project settings on the development machine for the M1 map.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. AsciiConfig resource (cell size, ramp, colors, enabled). 2. ascii_post.gdshader sampling hint_screen_texture per cell + glyph atlas. 3. AsciiPostProcess CanvasLayer(layer 0) rasterises atlas from SystemFont at runtime, sets uniforms. 4. Extend builders. 5. Validate headless + Movie Maker screenshot + fps.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented: scripts/rendering/ascii_config.gd, ascii_post_process.gd (CanvasLayer 0, glyph atlas rasterised at runtime from SystemFont into ImageTexture), shaders/ascii_post.gdshader, resources/config/ascii_config.tres, builders extended. Evidence: Movie Maker frame shows glyph grid (scratchpad/shots_003/frame00000019.png); with enabled=false the raw grey render shows (shots_003_off). --check-only clean, headless boot 0 ERROR. --print-fps at 1280x720 on GTX 1060: 60 FPS (vsync; project has no explicit max_fps, so target = monitor refresh 60Hz). Note: top-down ortho view currently shows only floor so image is uniform glyphs; walls not in frame.
<!-- SECTION:NOTES:END -->
