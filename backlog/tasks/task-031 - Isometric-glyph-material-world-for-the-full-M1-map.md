---
id: TASK-031
title: Isometric glyph-material world for the full M1 map
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T22:45:00Z'
updated_date: '2026-10-30T23:07:00Z'
labels:
  - rendering
  - world
milestone: m-5
dependencies: []
references:
  - scenes/spikes/glyph_world/glyph_world.tscn
documentation:
  - docs/architecture.md
priority: high
type: feature
ordinal: 32000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The user chose Spike A (scenes/spikes/glyph_world) as the direction. The real game still renders through the superseded full-screen ASCII post-process with a top-down camera. The game world needs to be rebuilt the Spike A way: real 3D geometry from the map file, isometric orthographic camera following the player, one glyph-surface material where light picks glyph density and colour.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 MapLoader builds the whole M1 map as merged meshes (few draw calls) with the glyph-surface material; the full-screen post-process is no longer in the main scene
- [ ] #2 The camera is isometric orthographic from the first frame and follows the player; values live in config resources
- [ ] #3 The player light drives glyph density and colour on nearby surfaces, as in Spike A
- [ ] #4 Walls never hide the player: walls between camera and player are cut away or faded
- [ ] #5 Draw calls, GPU time and FPS at 1366x768 and 1920x1080 with --max-fps 30 are recorded in the notes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Port Spike A shader to shaders/glyph_surface.gdshader (reveal mask, cut-away, camera-derived axes). 2. WorldMeshBuilder + MapLoader: one merged mesh. 3. GlyphWorldConfig/GlyphWorldView: lights + cut-away uniforms. 4. Isometric CameraViewConfig profile; remove AsciiPostProcess from main. 5. MapReveal via mask only. 6. Update tests, measure, capture, docs.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
IMPLEMENTED. Files: shaders/glyph_surface.gdshader, scripts/world/world_mesh_builder.gd, scripts/rendering/{glyph_world_view,glyph_world_config,glyph_light_source,glyph_surface_type,glyph_atlas_spec}.gd, resources/glyphs/{glyph_atlas.png,glyph_surface_material.tres}, resources/config/{camera_isometric,glyph_world_config}.tres, tools/{build_glyph_atlas,build_glyph_material,capture_glyph_world,measure_glyph_world}.gd; changed MapLoader, MapReveal (mask only, floor flag in alpha), CameraRig/ViewConfig, WorldConfig, RevealConfig (reveal_floor now true), overlay glyph height, build_main_scene, tests (camera_rig, map_loader, reveal, hazards), capture_at_size.sh (--max-fps 30), docs/architecture.md. AsciiPostProcess removed from main scene (files kept for task-035).

MEASURED (GTX 1060, --max-fps 30, 300 frames): 1366x768 opening: draws 4.2, prims 3338, GPU mean 0.42ms, 30.0 FPS; worst (radius 8 reveal, hazards): draws 3.9, prims 3313, GPU 0.58ms, 30.0 FPS. 1920x1061 (window clipped from 1080): opening GPU 1.02ms, worst 1.87ms (p99 3.56), 30.0 FPS. Raw: scratchpad/t031_perf.txt. Contact sheets: scratchpad/t031_contact_{world,reveal,hazards}_{1366,1920}.png. Tests: all tools/test_*.gd PASS headless except test_input_movement (same mouse-overshoot failure as before, identical numbers on stashed baseline: unchanged) and test_encoding (SKIP, needs GPU).
<!-- SECTION:NOTES:END -->
