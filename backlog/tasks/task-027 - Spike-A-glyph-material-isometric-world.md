---
id: TASK-027
title: 'Spike A: glyph-material isometric world'
status: To Do
assignee: []
created_date: '2026-10-30T21:53:00Z'
labels:
  - rendering
milestone: m-3
dependencies: []
documentation:
  - docs/architecture.md
priority: high
type: spike
ordinal: 28000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
decision-002 replaces the full-screen ASCII post-process with ASCII as a surface material on real 3D geometry seen isometrically (Illuminascii-style). Before rebuilding, a throwaway prototype must show whether this looks right and fits the potato budget (Intel HD 4000 class, 30+ FPS). Lives under scenes/spikes/ and must not change the main game.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A standalone spike scene shows part of the M1 map (walls, floor, an item, spikes, a corrupting patch) in an isometric camera, with glyph-atlas materials on all surfaces where light picks glyph density and brightness
- [ ] #2 A player light moves through the room (autopilot is fine) and glyphs on surfaces respond to it; emissive items/hazards use cheap halos, no full-screen post-process
- [ ] #3 Captures at 1920x1080 and 1366x768 are in the task notes, plus draw calls, GPU frame time and vertex count measured with --max-fps 30
- [ ] #4 The spike runs from one command or from god, documented in the task notes, so the user can try it on a low-end laptop
<!-- AC:END -->
