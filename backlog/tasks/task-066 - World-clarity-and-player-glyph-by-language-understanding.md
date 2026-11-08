---
id: TASK-066
title: World clarity and player glyph by language understanding
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T15:23:00Z'
updated_date: '2026-11-08T15:49:00Z'
labels:
  - rendering
dependencies:
  - TASK-065
priority: medium
type: feature
ordinal: 68000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
At 0% understanding the world looks as it does now (glyph surfaces of floor, hazards and props interleave). As understanding grows the layering becomes clear (floor below, hazards above, props like gargoyles on top) and the player glyph goes from a blunt hollow outline to its full glowing self.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Surface layering order floor < hazards < props; overlap glitch fades with understanding, current look at 0%, clean at 100%
- [x] #2 Player glyph: hollow, no glow below 6%; glow rises smoothly to today's level at 100%; colours blunt at 0%, slightly more vivid than today at 100%
- [x] #3 Driven by the selected language's understanding signal; tests and captured frames
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. World: layered glyph cells in glyph_surface.gdshader (ground-projected screen grid + owner search through a per-cell layer map built by GlyphWorldView), share of cells = clarity. 2. Gargoyle: silhouette backing Label3D in LargeObjectView. 3. Player/entity: hollow + colour grade uniforms, glow scaled on CPU from AvatarFxConfig. 4. Test tools/test_understanding_look.gd, all suites, captured frames.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
World clarity: fragments of floor / spikes / corruption / items / pushable objects are projected along the view ray to the floor; a per-cell hash < clarity picks the cell as layered; layered cells walk the cell-centre view ray through layer_map (RGBA8, per map cell: order*8+type, box height, half extent, near flag) and draw ONE glyph of the highest-order owner lit at the hit point. clarity 0 = exact old path (verified pixel-identical world crops vs baseline). Gargoyle: dark silhouette backing label (alpha = understanding). Player: hollow < 6%, glow (halo, crystal strength, sparkle) scaled 0 -> full from 6% to 100%, colour grade blunt (0.35 sat, 0.72 bright) -> vivid (1.15, 1.12); grown body follows hollow + grade. Config only (AvatarFxConfig 'Understanding look', GlyphWorldConfig 'Layered clarity'); no DB columns. Tests: new test_understanding_look PASS, all other suites PASS (3 known map failures skipped).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
glyph_surface: at clarity > 0 floor/hazard/item/object glyphs resolve on one screen-aligned floor grid; a share (= clarity) of cells walk the view ray through a small per-cell layer_map and draw only the highest-order owner (floor 0 < spikes/corruption 1 < items/objects 2); clarity 0 = old path unchanged (pixel-identical capture). Gargoyle: dark silhouette backing whose opacity follows understanding. Player glyph: hollow + no glow below 6%, glow rises to today's level at 100%, colour blunt (sat 0.35, bright 0.72) -> slightly vivid (1.15/1.12); grown body follows. Tests: test_understanding_look; captures at 0/50/100%. GPU cost not measured on target hardware.
<!-- SECTION:FINAL_SUMMARY:END -->
