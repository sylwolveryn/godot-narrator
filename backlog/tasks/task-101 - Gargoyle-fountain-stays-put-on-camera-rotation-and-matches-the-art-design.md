---
id: TASK-101
title: 'Gargoyle fountain: stays put on camera rotation and matches the art design'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-09T09:53:00Z'
labels:
  - rendering
  - art
  - bug
dependencies: []
priority: high
ordinal: 107000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The gargoyle fountain (G) is one flat Y-billboard of ASCII art standing on its footprint centre. When the camera orbits, the drawn basin swims against the floor cells it occupies and the whole prop reads as a cardboard cutout. It also looks nothing like the concept (docs/art: a dark winged gargoyle bust with glowing red eyes pouring luminous water into a square stone basin, all made of fine glyphs). It must stay potato-friendly (Compatibility renderer, 30+ FPS on HD 4000 class GPUs): pre-baked art, no runtime raymarching or extra render passes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The basin is anchored to the footprint cells and does not drift against the floor at any camera yaw
- [ ] #2 The statue keeps its place over the basin centre at any camera yaw and turns with the camera (pre-baked view angles)
- [ ] #3 The look follows the concept: dark winged bust, glowing red eyes, luminous water falling into a glowing basin
- [ ] #4 Runtime cost stays in the potato budget (no per-frame text rebuilds beyond the animated layer, a handful of draw calls per fountain)
- [ ] #5 Reveal, memory tint, destruction and restore still work; existing large-object tests pass
- [ ] #6 Leftover polish ideas are recorded in a 'Polishing UI' task
<!-- AC:END -->
