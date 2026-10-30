---
id: TASK-022
title: 'Visual direction: neon ASCII and true glyph morphing'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-30T17:45:00Z'
updated_date: '2026-10-30T17:49:00Z'
labels:
  - rendering
milestone: m-2
dependencies: []
priority: high
type: docs
ordinal: 25000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Playtest: colours are dull and the glyph changes hurt the eyes; changes are hard swaps, not morphs. The moodboard in docs/art (neon sunset, midnight cavern) shows the target: glowing glyphs, rich per-region colour, density and depth. A short spec is needed before the shader and effects are reworked.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 docs/visual_direction.md defines the palette (per cell type, memory style, hazards, player, narration), glow/bloom, depth cues and motion rules
- [x] #2 It defines what a morph is (continuous shape interpolation between glyphs, not swaps) and limits on flicker (rate, contrast, area)
- [x] #3 All values it sets are listed as config-resource tunables
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
game-designer wrote docs/visual_direction.md ("Midnight Neon"): data-encoded unshaded world materials → post shader with per-type glyph ramps, SDF glyph atlas and palette LUT; player light, glow/bloom, vignette and depth falloff; morph = SDF blend (ramp morph driven by luminance, so brightness changes morph automatically); flicker caps (~0.5 Hz, area limits, breathing corruption); overlay glyphs drawn as SDF quads so they morph too; full tunables table and a ~5 ms GTX 1060 budget with fallbacks. Implies an architecture.md Rendering update (done with task-023/024).
<!-- SECTION:FINAL_SUMMARY:END -->
