---
id: TASK-030
title: Glyph storm effect (from Spike B)
status: To Do
assignee: []
created_date: '2026-10-30T22:44:00Z'
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
- [ ] #1 A storm effect can be triggered in the real game for a chosen moment (to be designed)
- [ ] #2 It holds 30 FPS on the target low-end GPU, with no frame hitch when it starts
<!-- AC:END -->
