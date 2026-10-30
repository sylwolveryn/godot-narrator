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
