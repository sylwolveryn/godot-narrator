---
id: TASK-102
title: >-
  Sight performance pass: budgeted reveal and light-occlusion sweeps,
  view-limited shadows
status: Done
assignee:
  - '@claude'
created_date: '2026-11-09T10:22:00Z'
updated_date: '2026-11-09T10:22:00Z'
labels:
  - perf
dependencies: []
ordinal: 108000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Large run-only sight scales (god mod --sight up to 1000%) made the per-move sight work explode (cubic in the radius): player-light occlusion took ~14 ms per cell step at 100%, ~850 ms at 400% and ~16 s at 1000%; the reveal sweep ~390 ms at 1000%. Also tune the narration debug overlay cost.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Ray loops read a lazily classified GridMask instead of MapData.type_at per step
- [x] #2 Reveal and occlusion sweeps run within a per-frame ms budget (exported), nearest cells first
- [x] #3 Player-light shadows are computed only within the camera view on the floor (off-screen culling)
- [x] #4 Shadows recompute on cell change / light / wall changes only, not on every reveal
- [x] #5 At 1000% sight the walking frame cost matches 100% (tools/bench_sight_live.gd)
- [x] #6 Narration debug overlay caches shaped text, redraws at 5 Hz and shows its own draw time
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
GridMask (lazy per-sweep blocker box) replaces MapData.type_at in SightLine/GlyphLightOcclusion ray loops; MapReveal and the player-light occlusion are now budgeted jobs (RevealConfig.sweep_budget_ms / resweep_distance_cells, GlyphWorldConfig.occlusion_budget_ms / occlusion_view_margin_cells); shadows are limited to the camera's floor view and no longer recompute on every reveal. tools/bench_sight.gd (full-field cost: occlusion 13.9->4.3 ms at 100%, 16.2 s->3.0 s unbudgeted at 1000%) and tools/bench_sight_live.gd (walking on m5_shapes at 1000%: worst physics 13 ms, same as 100%). test_reveal, test_light_occlusion, test_dirt, test_cannon, test_narrator pass. Not done: chunking the single world mesh for GPU frustum culling (65k verts on 200x200; judged low value). Shadows can trail the player by a few frames at huge sight scales.
<!-- SECTION:FINAL_SUMMARY:END -->
