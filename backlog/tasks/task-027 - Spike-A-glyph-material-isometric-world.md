---
id: TASK-027
title: 'Spike A: glyph-material isometric world'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T21:53:00Z'
updated_date: '2026-10-30T21:56:00Z'
labels:
  - rendering
milestone: m-3
dependencies: []
documentation:
  - docs/architecture.md
priority: high
type: spike
ordinal: 28000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
decision-002 replaces the full-screen ASCII post-process with ASCII as a surface material on real 3D geometry seen isometrically (Illuminascii-style). Before rebuilding, a throwaway prototype must show whether this looks right and fits the potato budget (Intel HD 4000 class, 30+ FPS). Lives under scenes/spikes/ and must not change the main game.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A standalone spike scene shows part of the M1 map (walls, floor, an item, spikes, a corrupting patch) in an isometric camera, with glyph-atlas materials on all surfaces where light picks glyph density and brightness
- [ ] #2 A player light moves through the room (autopilot is fine) and glyphs on surfaces respond to it; emissive items/hazards use cheap halos, no full-screen post-process
- [ ] #3 Captures at 1920x1080 and 1366x768 are in the task notes, plus draw calls, GPU frame time and vertex count measured with --max-fps 30
- [ ] #4 The spike runs from one command or from god, documented in the task notes, so the user can try it on a low-end laptop
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. tools/build_spike_glyph_atlas.gd: render monospace glyph atlas (5 ramps x 8 + specials) via SubViewport once -> PNG in scenes/spikes/glyph_world/.
2. shaders: glyph_surface.gdshader (single world material: per-face glyph grid, ramp by lit brightness from <=8 analytic lights, palette per type id in vertex COLOR), glyph_halo.gdshader (additive billboards, one merged mesh), glyph_marker.gdshader (player glyph billboard).
3. tools/build_spike_glyph_world.gd: M1 slice (x12-27,y2-13) -> one merged ArrayMesh (floor, walls, spikes, corrupt, item pillars), halo meshes, camera, scene saved headless.
4. glyph_world.gd autopilot + light uniforms; spike_perf_logger.gd + capture via args.
5. Measure at 1920x1080 and 1366x768 with --max-fps 30; iterate look vs gargoyle moodboard; record notes.
<!-- SECTION:PLAN:END -->
