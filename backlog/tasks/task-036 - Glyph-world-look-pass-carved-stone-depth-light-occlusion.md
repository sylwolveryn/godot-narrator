---
id: TASK-036
title: 'Glyph world look pass: carved stone, depth, light occlusion'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T22:45:00Z'
updated_date: '2026-10-31T08:25:00Z'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Shader: carved stone (blocks, seams, rims, foot AO), depth (ambient distance fade, top fog), glyph-cell cut-away dissolve. 2. CPU grid raycast occlusion (GlyphLightOcclusion) into per-slot visibility textures (GlyphVisibilityMap), static lights baked, player light blended. 3. Static light fade in/out in GlyphWorldView. 4. Config in GlyphWorldConfig. 5. Test, captures, perf.
<!-- SECTION:PLAN:END -->
