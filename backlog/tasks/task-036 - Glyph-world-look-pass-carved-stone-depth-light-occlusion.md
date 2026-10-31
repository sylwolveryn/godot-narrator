---
id: TASK-036
title: 'Glyph world look pass: carved stone, depth, light occlusion'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-30T22:45:00Z'
updated_date: '2026-10-31T08:29:00Z'
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
- [x] #1 Wall faces read as carved stone, with brighter edges and denser glyphs near light
- [x] #2 Distance or depth darkening gives the scene depth without hurting readability
- [x] #3 Light does not visibly leak through walls (cheap approximation is fine)
- [x] #4 Before/after captures and FPS at 1366x768 with --max-fps 30 are in the notes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Shader: carved stone (blocks, seams, rims, foot AO), depth (ambient distance fade, top fog), glyph-cell cut-away dissolve. 2. CPU grid raycast occlusion (GlyphLightOcclusion) into per-slot visibility textures (GlyphVisibilityMap), static lights baked, player light blended. 3. Static light fade in/out in GlyphWorldView. 4. Config in GlyphWorldConfig. 5. Test, captures, perf.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
IMPLEMENTED (not committed). Files: shaders/glyph_surface.gdshader, scripts/world/world_mesh_builder.gd (edge bits COLOR.g, under-wall flag COLOR.b), scripts/rendering/{glyph_light_occlusion,glyph_visibility_map}.gd (new), glyph_light_source.gd, glyph_world_view.gd, glyph_world_config.gd, tools/test_light_occlusion.gd (new), tools/capture_glyph_world.gd (schedule +spawn/wall_corner/wall_between), docs/architecture.md. EVIDENCE: sheets in scratchpad t036_contact_{1366,1920}_{a,b}.png (before vs after: spawn, wall_corner, wall_between, cutaway_on, south_spikes, north_room); perf raw t036_perf.txt. PERF (GTX1060, --max-fps 30, 30 FPS, 4.2 draws, 3337 prims): 1366x768 after GPU opening 0.69-1.37 ms / worst 0.71-1.26; same-session baseline opening 0.55-0.82 / worst 0.83-1.05 (GPU timer noisy, within ~1.5x). 1080p after opening 0.91 / worst 0.89. Shader adds 1-2 texture fetches (vis A, B only if >4 lights). Player occlusion recompute 1.5 ms per cell change on dev PC. Tests: all tools/test_*.gd PASS incl. new test_light_occlusion; boot 0 ERROR; progress.tres hash unchanged. Unresolved: cutaway_on/spawn capture marks show only tiny reveal (use wall_corner for cut-away edge); look tuned by eye, rims intentionally faint away from light to avoid wireframe look; not yet checked on real low-end HW.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Carved-stone walls (masonry blocks, seams, per-block variation, lit rims, darker feet), depth falloff + faint top fog, and light occlusion via CPU grid raycasts into small visibility textures (player light recomputed on cell change and blended; static lights baked at map build). Cut-away now dissolves per glyph cell; static lights fade in/out. About 4 draw calls, 30 FPS, GPU within ~1.5x of the same-session baseline on a GTX 1060. Validator PASS; new tools/test_light_occlusion.gd. Tradeoff: the scene is noticeably darker/sparser than task-031; ambient and rim values in glyph_world_config.tres may need a brighter retune after playtest. Risk: occlusion recompute costs ~1.5 ms per cell change on the dev PC (more on low-end CPUs), check in task-037.
<!-- SECTION:FINAL_SUMMARY:END -->
