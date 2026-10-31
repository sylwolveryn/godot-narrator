---
id: TASK-032
title: Reveal and memory on glyph surfaces
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T22:45:00Z'
updated_date: '2026-10-31T09:16:00Z'
labels:
  - rendering
  - world
milestone: m-5
dependencies:
  - TASK-031
priority: high
type: feature
ordinal: 33000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Reveal (hidden until near) and remembered cells from earlier runs were built for the old renderer. They need to work on the new glyph-surface world: unseen cells dark, cells fading in as they are revealed, remembered cells shown in a dim cool style.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 At run start only cells within the reveal radius are visible; revealed cells fade in calmly
- [x] #2 Remembered cells from earlier runs show in a dim, cool style that is readable but clearly different from lit cells
- [x] #3 tools/test_reveal.gd passes against the new renderer without weakening its checks
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Shader: per-glyph materialise during reveal fade, memory look (cool tint, sparser, floor density, reduced glow). 2. RevealConfig: radius 2.75, slower smoothstep fade; remove per-frame array alloc; cells_seen signal so static lights re-pick. 3. Static lights only for cells seen this run. 4. Extend tools/test_reveal.gd (fade no-flicker, memory->live smooth). 5. Capture tool + sheets at 1366/1080, measure perf, docs.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
IMPLEMENTED (not committed). Files: shaders/glyph_surface.gdshader (reveal_spread per-glyph materialise, memory_tint/density/dropout/floor/emit uniforms, memory cells get no light tint), scripts/rendering/{glyph_world_config,glyph_world_view}.gd (new Memory/Reveal config values; static lights only for cells SEEN this run; re-pick on MapReveal.cells_seen), scripts/world/{map_reveal,reveal_config}.gd (radius 2.0->2.75, fade 0.5->0.9s, stagger .025->.07, overshoot 1.15->1.06, memory->seen 0.35->0.7s, smoothstep growth, reusable finished list = no per-frame alloc, cells_seen signal), tools/test_reveal.gd (extended: no dip before peak, memory->live transition monotonic, no dark flash, intermediate frames), tools/capture_reveal_memory.gd (new), docs/architecture.md, docs/game_design.md. Halos: halo_memory stays 0 (off on memory, fade with the mask). Mask uploaded only when dirty/animating (unchanged). EVIDENCE: sheets scratchpad t032_contact_{1366,1920}_{a,b}.png (a: run-1 opening + 5-frame materialise strip, b: run-1 end, run-2 memory, re-seen strip, run-2 end); baseline t032_a.png. PERF GTX1060 --max-fps 30 30 FPS: 1366x768 opening GPU 0.62ms draws 4.2 prims 3453, worst 0.77ms; 1920x1061 opening 0.77ms, worst 1.06ms (raw t032_perf.txt). Tests: all tools/test_*.gd PASS headless, boot 0 ERROR, progress.tres md5 unchanged. Unresolved: tuned by eye on dev PC, not real low-end HW; memory floors can still read slightly tan under the warm light; remembered cells appear instantly at run start (no fade-in).
<!-- SECTION:NOTES:END -->
