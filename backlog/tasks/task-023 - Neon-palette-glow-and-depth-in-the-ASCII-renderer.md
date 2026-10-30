---
id: TASK-023
title: Neon palette, glow and depth in the ASCII renderer
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T17:45:00Z'
updated_date: '2026-10-30T18:08:00Z'
labels:
  - rendering
milestone: m-2
dependencies:
  - TASK-022
documentation:
  - docs/visual_direction.md
priority: high
type: feature
ordinal: 26000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The current renderer flattens everything to grey-blue glyphs on black; the moodboard look needs colour, light and depth.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Walls, floor, items, hazards, memory cells, player and narration use the palette from docs/visual_direction.md
- [ ] #2 Bright glyphs glow (bloom or equivalent) without blurring glyph shapes into unreadable blobs
- [ ] #3 Captures before/after are compared side by side in the task notes
- [ ] #4 Frame rate stays at 60 FPS at 1920x1080 on the dev machine
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Shared GlyphAtlas (GPU SDF bake at boot, SubViewport + brute-force SDF shader) + glyph_sdf.gdshaderinc + reusable glyph_morph canvas shader.
2. World materials: spatial world_encode shader (R id, G luminance incl. player light/reveal/hazard pulse, B state/noise) from global shader params + reveal_mask texture (MapReveal owns it).
3. Palette: PaletteConfig gradients -> 256x16 LUT built at boot; LightConfig; HazardFxConfig; AsciiConfig tunables from the spec table.
4. New ascii_post shader: texelFetch cell centre, decode, ramp+palette by id, SDF glyph, glow/bloom, vignette, DOF, memory cap.
5. Verify encoding with a test pattern; run all tests; captures before/after at 1920x1080; tune until it matches the moodboard mood.
6. Perf at 1920x1080; architecture.md Rendering update.
<!-- SECTION:PLAN:END -->
