---
id: TASK-027
title: 'Spike A: glyph-material isometric world'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-30T21:53:00Z'
updated_date: '2026-10-30T22:27:00Z'
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
- [x] #1 A standalone spike scene shows part of the M1 map (walls, floor, an item, spikes, a corrupting patch) in an isometric camera, with glyph-atlas materials on all surfaces where light picks glyph density and brightness
- [x] #2 A player light moves through the room (autopilot is fine) and glyphs on surfaces respond to it; emissive items/hazards use cheap halos, no full-screen post-process
- [x] #3 Captures at 1920x1080 and 1366x768 are in the task notes, plus draw calls, GPU frame time and vertex count measured with --max-fps 30
- [x] #4 The spike runs from one command or from god, documented in the task notes, so the user can try it on a low-end laptop
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. tools/build_spike_glyph_atlas.gd: render monospace glyph atlas (5 ramps x 8 + specials) via SubViewport once -> PNG in scenes/spikes/glyph_world/.
2. shaders: glyph_surface.gdshader (single world material: per-face glyph grid, ramp by lit brightness from <=8 analytic lights, palette per type id in vertex COLOR), glyph_halo.gdshader (additive billboards, one merged mesh), glyph_marker.gdshader (player glyph billboard).
3. tools/build_spike_glyph_world.gd: M1 slice (x12-27,y2-13) -> one merged ArrayMesh (floor, walls, spikes, corrupt, item pillars), halo meshes, camera, scene saved headless.
4. glyph_world.gd autopilot + light uniforms; spike_perf_logger.gd + capture via args.
5. Measure at 1920x1080 and 1366x768 with --max-fps 30; iterate look vs gargoyle moodboard; record notes.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
SPIKE A built (throwaway, isolated in scenes/spikes/glyph_world/ + tools/build_spike_glyph_atlas.gd, tools/build_spike_glyph_world.gd).
RUN: godot --path . --max-fps 30 res://scenes/spikes/glyph_world/glyph_world.tscn   (optional user args after --: size=1366x768 perf=300 shots=<dir>). Rebuild: godot --path . --max-fps 30 -s tools/build_spike_glyph_atlas.gd (needs a renderer, NOT headless) then godot --headless --path . -s tools/build_spike_glyph_world.gd.
DESIGN: M1 slice x12-27,y2-13 (16x12) as real 3D: ONE merged mesh (floor, walls h=1.0, spike pyramids, corruption columns, item pillars) + ONE ShaderMaterial (glyph_surface.gdshader, type id in vertex COLOR). Glyph grid in world space per face (top: screen-aligned axes, sides: surface-aligned), light evaluated per glyph cell from <=8 analytic point lights (player + 2 items + 2 spike strips + corruption), brightness picks glyph from per-type ramp row of a generated 8x6 atlas (scenes/spikes/glyph_world/glyph_atlas.png), per-type colour gradient, slow calm per-cell breathing, slice edge fade. Halos = one merged additive billboard mesh (13 quads, 1 draw) + 1 player halo quad; player marker = 1 glyph quad. No shadows, no WorldEnvironment glow, no post-process, no screen reads.
MEASURED (GTX 1060 dev PC, Compatibility, --max-fps 30, 300 frames after 120 warm-up): 1920x1080: draw_calls 4.0, primitives 638 (608 world tris = 1824 verts + halos), video mem 22.2 MB, GPU 0.80 ms, CPU render 0.34 ms, 30.0 fps. 1366x768: draw_calls 4.0, primitives 638, video mem 14.4 MB, GPU 0.29 ms (0.8 vs 0.29 includes timer noise; pixel ratio is 2x), 30.0 fps. Raw: C:/Users/SYLWOL~1/AppData/Local/Temp/claude/E--git-godot-narrator/9bf6ff4a-2b4c-4f5c-8bbc-2621e15c92c1/scratchpad/spikeA_perf.txt
SHADER COST: surface fragment = 1 textureGrad atlas fetch (L8, mipmapped), 0 dependent fetches, loop over up to 7 active lights (~15 ALU each, one sqrt/length each) + 1 hash + pow + a few mixes; branches: top/side face select, light_count break, t==3 corruption hue, t>=2 tint select (all uniform or per-primitive coherent). Vertex: trivial. Halo: 0 fetches, 1 exp. Marker: 1 fetch.
CAPTURES (viewport screenshots in-scene, not Movie Maker): contact sheets C:/Users/SYLWOL~1/AppData/Local/Temp/claude/E--git-godot-narrator/9bf6ff4a-2b4c-4f5c-8bbc-2621e15c92c1/scratchpad/spikeA_contact_1920x1080.png and C:/Users/SYLWOL~1/AppData/Local/Temp/claude/E--git-godot-narrator/9bf6ff4a-2b4c-4f5c-8bbc-2621e15c92c1/scratchpad/spikeA_contact_1366x768.png ; frames in C:/Users/SYLWOL~1/AppData/Local/Temp/claude/E--git-godot-narrator/9bf6ff4a-2b4c-4f5c-8bbc-2621e15c92c1/scratchpad/spikeA_final_1920x1080/ and C:/Users/SYLWOL~1/AppData/Local/Temp/claude/E--git-godot-narrator/9bf6ff4a-2b4c-4f5c-8bbc-2621e15c92c1/scratchpad/spikeA_final_1366x768/ shot_00..07.png ; iteration history spikeA_try1..try6.
CAVEATS: GPU timing on a GTX 1060 says nothing absolute about HD 4000; estimate ~15-30x slower ALU -> roughly 12-24 ms at 1080p, 6-12 ms at 1366x768 worst case (full-screen coverage is only ~35% of pixels here, rest is black clear) - to be confirmed on real hardware. Lights pass through walls (no occlusion); walls hide the far room from the +x+z iso camera (h=1.0 compromise).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Throwaway spike built and validated (godot-validator PASS: no errors, main game untouched). Launch from god (Prototypes row) or the command in the notes. GTX 1060 numbers are in the notes; real low-end laptop check and the direction choice are pending with the user.
<!-- SECTION:FINAL_SUMMARY:END -->
