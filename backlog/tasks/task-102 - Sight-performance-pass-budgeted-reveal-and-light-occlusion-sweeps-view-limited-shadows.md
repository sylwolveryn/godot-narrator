---
id: TASK-102
title: >-
  Sight performance pass: budgeted reveal and light-occlusion sweeps,
  view-limited shadows
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-09T10:22:00Z'
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
- [ ] #1 Ray loops read a lazily classified GridMask instead of MapData.type_at per step
- [ ] #2 Reveal and occlusion sweeps run within a per-frame ms budget (exported), nearest cells first
- [ ] #3 Player-light shadows are computed only within the camera view on the floor (off-screen culling)
- [ ] #4 Shadows recompute on cell change / light / wall changes only, not on every reveal
- [ ] #5 At 1000% sight the walking frame cost matches 100% (tools/bench_sight_live.gd)
- [ ] #6 Narration debug overlay caches shaped text, redraws at 5 Hz and shows its own draw time
<!-- AC:END -->
