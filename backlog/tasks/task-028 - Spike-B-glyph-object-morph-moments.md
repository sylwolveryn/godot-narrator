---
id: TASK-028
title: 'Spike B: glyph-object morph moments'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T21:53:00Z'
updated_date: '2026-10-30T22:21:00Z'
labels:
  - rendering
  - player
  - narrator
  - ux
milestone: m-3
dependencies: []
documentation:
  - docs/architecture.md
priority: high
type: spike
ordinal: 29000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
decision-002 defines morph as many glyph objects that fly, rotate and reassemble (Effulgence-style). A throwaway prototype must show three key moments and prove they are cheap enough (batched glyph quads, potato budget). Lives under scenes/spikes/ and must not change the main game.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Hero grows: a single-glyph hero rearranges into a larger multi-glyph entity and back
- [ ] #2 Surroundings to menu: nearby world glyphs lift off and rearrange into readable menu items, then return
- [ ] #3 Narration assembles: letters fly in to form a readable sentence, hold, then disperse
- [ ] #4 All glyph objects are batched (e.g. MultiMeshInstance3D or one canvas batch); captures, draw calls and GPU frame time at --max-fps 30 are in the task notes, and the spike runs from one command or from god
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Glyph atlas baked by tool (SubViewport -> PNG). 2. ONE MultiMeshInstance3D, billboard quads, premul-alpha shader with built-in halo; morph evaluated in the vertex shader from start/end data + one time uniform (CPU path kept only for comparison). 3. Moments 1 hero grows, 2 menu, 3 narration (+4 storm stress). 4. Capture with Movie Maker, iterate, measure draw calls/GPU/CPU at 1080p and 768p, stress 500/2000/5000.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Spike B built (throwaway). Run: godot --path . --max-fps 30 res://scenes/spikes/glyph_morph/glyph_morph.tscn  (keys 1/2/3 trigger moments, 4 = all-glyph storm; args after --: moment=N count=N cpu hud=0 perf quit=SEC). Files: scenes/spikes/glyph_morph/*, tools/build_spike_glyph_morph.gd (headless scene builder), tools/build_spike_glyph_atlas.gd (GPU atlas bake), tools/spike_glyph_morph_run.sh (perf/capture at exact size).
Design: 695 glyph instances in ONE MultiMesh (2 draw calls total: floor + glyphs; 3 with HUD label). Morph math runs in the vertex shader (eased overshoot path, arc, spin, scale pop, mid-flight glyph flip, colour fade) from per-instance start/end/timing + one morph_t uniform -> CPU per frame ~0.006 ms. Halo is part of the same quad via blend_premul_alpha (additive where alpha=0), no WorldEnvironment/post.
Numbers (loop of all 3 moments, --max-fps 30, GTX 1060, other godot agents running concurrently so noisy): 1920x1061 window: draws 2.0, primitives 1392, GPU 0.74 ms during morph / 0.78 idle, script field cost 0.005 ms, frame max 33.3 ms (no hitches). 1366x768: draws 2.0, prims 1392, GPU 0.26 / 0.28 ms.
Stress, storm moment (ALL glyphs move) at 1080p, shader-anim vs CPU-anim: 500 glyphs GPU 1.0/0.3 ms, script 0.006/0.95 ms; 2000 glyphs GPU 0.5/1.0, script 0.005/3.7 ms; 5000 glyphs GPU 0.65/0.66, script 0.005/9.2 ms. Draw calls stay 2 in every case; primitives = 2 x instances. One-off morph-build cost (GDScript filling the buffer) 2.8 ms @500, 11 ms @2000, 42 ms @5000 (a single dropped frame at 5000; ~1 ms for the ~100 glyphs real moments move). Shader-anim chosen: zero per-frame CPU, constant cost, scales with instance count only on the GPU.
Captures (scratchpad): C:/Users/SYLWOL~1/AppData/Local/Temp/claude/E--git-godot-narrator/9bf6ff4a-2b4c-4f5c-8bbc-2621e15c92c1/scratchpad/spikeB_hero_1080_sheet.png, spikeB_menu_1080_sheet.png, spikeB_narration_1080_sheet.png, spikeB_strip_hero_grow.png, spikeB_strip_narration.png (same folder; frame dirs spikeB_cap1..3).
<!-- SECTION:NOTES:END -->
