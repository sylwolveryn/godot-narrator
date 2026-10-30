---
id: TASK-023
title: Neon palette, glow and depth in the ASCII renderer
status: Done
assignee:
  - '@claude'
created_date: '2026-10-30T17:45:00Z'
updated_date: '2026-10-30T20:39:00Z'
labels:
  - rendering
milestone: m-2
dependencies:
  - TASK-022
documentation:
  - docs/visual_direction.md
priority: high
type: feature
ordinal: 26000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The current renderer flattens everything to grey-blue glyphs on black; the moodboard look needs colour, light and depth.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Walls, floor, items, hazards, memory cells, player and narration use the palette from docs/visual_direction.md
- [x] #2 Bright glyphs glow (bloom or equivalent) without blurring glyph shapes into unreadable blobs
- [x] #3 Captures before/after are compared side by side in the task notes
- [x] #4 Frame rate stays at 60 FPS at 1920x1080 on the dev machine
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Shared GlyphAtlas (GPU SDF bake at boot, SubViewport + brute-force SDF shader) + glyph_sdf.gdshaderinc + reusable glyph_morph canvas shader.
2. World materials: spatial world_encode shader (R id, G luminance incl. player light/reveal/hazard pulse, B state/noise) from global shader params + reveal_mask texture (MapReveal owns it).
3. Palette: PaletteConfig gradients -> 256x16 LUT built at boot; LightConfig; HazardFxConfig; AsciiConfig tunables from the spec table.
4. New ascii_post shader: texelFetch cell centre, decode, ramp+palette by id, SDF glyph, glow/bloom, vignette, DOF, memory cap.
5. Verify encoding with a test pattern; run all tests; captures before/after at 1920x1080; tune until it matches the moodboard mood.
6. Perf at 1920x1080; architecture.md Rendering update.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented (files): shaders/world_encode.gdshader + world_encoding.gdshaderinc (data-encoded 3D: R id, G luminance incl. light/reveal/pulse, B state), shaders/ascii_post.gdshader (SDF glyph, palette LUT, glow, bloom, rim, DOF, vignette, dither), glyph_sdf.gdshaderinc, glyph_sdf_bake.gdshader, glyph_morph.gdshader; scripts/rendering/{glyph_atlas,palette_config,light_config,hazard_fx_config,material_ids,ascii_config,ascii_post_process}.gd; MapLoader (ShaderMaterials), MapReveal (reveal_mask texture + animations), RevealConfig/WorldConfig/GlyphFxConfig; tools builders updated; project.godot gets [shader_globals]. docs/architecture.md Rendering rewritten.
Encoding evidence: tools/test_encoding.gd (GPU, SKIPs headless) draws 147 known id/L/state cases and decodes like the post shader: PASS, worst luminance error 0.0029, palette offset 0.0242, memory 0.0049. Finding: compat returns ALBEDO raw but values below ~0.2 come back up to 5/255 low, so every channel starts at 0.2 (ids 0.25+0.045*id); clear colour decodes as void.
Visual: before/after sheet C:/Users/SYLWOL~1/AppData/Local/Temp/claude/E--git-godot-narrator/9bf6ff4a-2b4c-4f5c-8bbc-2621e15c92c1/scratchpad/sheet_023_before_after.png (opening, walked, run-2 memory, run-2 walking; 1920x1080); hazards/idle scene C:/Users/SYLWOL~1/AppData/Local/Temp/claude/E--git-godot-narrator/9bf6ff4a-2b4c-4f5c-8bbc-2621e15c92c1/scratchpad/sheet_023_hazards.png; raw frames in C:/Users/SYLWOL~1/AppData/Local/Temp/claude/E--git-godot-narrator/9bf6ff4a-2b4c-4f5c-8bbc-2621e15c92c1/scratchpad/shots_023_before, shots_023_after, shots_023_a, shots_023_idle. Atlas dump C:/Users/SYLWOL~1/AppData/Local/Temp/claude/E--git-godot-narrator/9bf6ff4a-2b4c-4f5c-8bbc-2621e15c92c1/scratchpad/atlas_023.png.
Perf (tools/measure_perf.gd, 1920x1061 window, spikes+item+corruption in view): vsync on 16.67 ms mean, p99 16.91 ms (60 FPS held), GPU render 1.19 ms mean / 2.14 max; vsync off 0.89 ms mean (1118 FPS), GPU 0.48 ms mean. Atlas bake 87-110 ms wall at boot incl. 3 frame waits (spec <50 ms is for compute only; bake fallback not needed).
Tuning deviations from spec defaults (documented in configs): light radii are glyph cells (12/24 instead of 6/11, to cover the 2-cell reveal radius), bg_pool_strength 0.22 (amber pool on empty background), bloom_strength 0.2 (0.5 filled corruption patches with solid fog), wall_luminance 0.75, hue_noise_detail 1.0 (extra field), atlas_font_scale 1.1. Overlay colours: PlayerConfig glyph #FFF6E6 + amber outline, narration #EAF2FF, intro wave cyan.
Tests: all tools/test_*.gd PASS (test_reveal updated to assert the mask look: memory (1,0,0), seen (1,1,0), reveal overshoot peak <=1.15, starts dark); boot has 0 ERROR lines; progress.tres md5 unchanged (5935d363...). Not done: overlay (player/erosion/death/narration) morphing is task-025; floor is hidden by default (reveal_floor=false) so the floor palette row is built but not seen.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
World renderer rebuilt per docs/visual_direction.md: unshaded world materials encode material id / luminance / state; the post shader picks per-type glyph ramps from a GPU-baked SDF atlas and colours them from a palette LUT, with player light pool, own-cell halo, 4-neighbour bloom, wall rim glow, depth falloff, vignette and static dither. Encoding verified by tools/test_encoding.gd (non-headless, 147 cases). 60 FPS at 1920x1080 (GPU ~1.2 ms). Tuned defaults differ from the spec (light radii 12/24 cells, bloom 0.2). Density/brightness still short of the moodboard → task-026.
<!-- SECTION:FINAL_SUMMARY:END -->
