---
id: TASK-030
title: Glyph storm effect (from Spike B)
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T22:44:00Z'
updated_date: '2026-11-02T10:38:00Z'
labels:
  - rendering
milestone: m-4
dependencies: []
references:
  - scenes/spikes/glyph_morph/glyph_morph_demo.gd
priority: low
type: feature
ordinal: 31000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The user loved the "storm" in Spike B (key 4 in scenes/spikes/glyph_morph): every nearby glyph lifts off at once and swirls before settling. Keep it as a future effect, e.g. for corruption bursts, big narrative moments or run transitions. Reference implementation: scenes/spikes/glyph_morph/glyph_morph_demo.gd (STORM_* constants) and glyph_morph_field.gd / glyph_morph.gdshader (vertex-shader morph, one MultiMesh). Note the one-off build hitch scales with glyph count (about 42 ms at 5000 glyphs), so budget it for low-end GPUs.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A storm effect can be triggered in the real game for a chosen moment (to be designed)
- [ ] #2 It holds 30 FPS on the target low-end GPU, with no frame hitch when it starts
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. StormConfig resource + tools/build_storm.gd. 2. GlyphStormView + shaders/glyph_storm.gdshader: one MultiMesh allocated once, no per-instance data (shader derives everything from INSTANCE_ID + seed, reads source_map + reveal_mask). 3. Trigger: origin_struck + SignalBus.glyph_storm_requested. 4. storm_zone dim in glyph_surface shader. 5. Wire in build_main_scene. 6. tools/test_glyph_storm.gd, capture_storm.gd, measure '-- storm'. 7. Docs.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented. Trigger: SignalBus.origin_struck (tint per nature) and generic SignalBus.glyph_storm_requested(centre, radius, duration, tint). Start cost (CPU, Time.get_ticks_usec around start_storm, ~10 uniforms): mean 13 us, worst 42 us over 20 starts (tools/test_glyph_storm.gd, dev PC); MultiMesh preallocated at 800 instances, shader compiled by a 2-frame warm-up at load, so no build/compile hitch. Perf (tools/measure_glyph_world.gd -- storm, 1920x1080, GTX 1060, 30 fps capped): frame 33.33 ms mean in both cases; draw calls 5.8 -> 6.7 (opening) (+1 for the storm; measure counts include overhead); GPU ms opening 0.58 -> 0.69, wide-reveal worst case 0.72 -> 1.73 mean. NOT measured on an Intel HD 2500/4000 (none available), so AC2 left unchecked pending that. Tests: tools/test_glyph_storm.gd PASS; all tools/test_*.gd PASS; headless boot zero ERROR. Visual: contact sheets in scratchpad t030_strip_1366.png, t030_zoom_1366.png, t030_strip_1920.png (lift, swirl, settle; ai cyan, demonic red). Docs updated: architecture.md, game_design.md.

Validated (validator PASS) and committed. Storm start costs ~12 us mean (uniforms only), 30 FPS held on the dev GTX 1060 (+1 draw call, GPU 0.7-1.7 ms at 1080p). AC #2 (30 FPS on the target low-end GPU) stays open until the user laptop check (task-037).
<!-- SECTION:NOTES:END -->
