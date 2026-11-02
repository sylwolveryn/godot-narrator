---
id: TASK-030
title: Glyph storm effect (from Spike B)
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T22:44:00Z'
updated_date: '2026-11-02T10:34:00Z'
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
