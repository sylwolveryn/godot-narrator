---
id: TASK-004
title: 'Spike: narration and menu overlay vs. ASCII shader'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T15:30:00Z'
updated_date: '2026-10-30T16:05:00Z'
labels:
  - rendering
  - narrator
  - ux
milestone: m-0
dependencies:
  - TASK-002
  - TASK-003
documentation:
  - docs/game_design.md
priority: high
type: spike
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A full-screen shader will scramble narration text and in-world menus if they are drawn in the 3D scene, and this risk is unresolved. The spike must pick between an overlay layer that bypasses the shader and text designed to survive it, so later narrator and menu work does not build on the wrong approach.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A written decision is recorded as a Backlog decision (`backlog decision create`) choosing overlay bypass or shader-safe text, or a documented hybrid.
- [x] #2 A throwaway prototype shows a line of text readable on top of the shader output using the chosen approach.
- [x] #3 The decision states how the character identity from the shader cell size question is affected, or lists it as an open item.
- [x] #4 Open items are added to `docs/game_design.md` Open Questions.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Throwaway prototype tools/spike_overlay.gd: runs main scene + CanvasLayer(layer 10) with Label and a glyph at camera.unproject_position of a 3D point. 2. Movie Maker capture, view. 3. Record decision. 4. Update game_design.md risks.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Prototype tools/spike_overlay.gd (deleted afterwards) captured via Movie Maker: crisp Label and a '@' at unproject_position((3,0,-2)) over ASCII output (scratchpad/shots_004/f00000028.png). Decision decision-001 recorded; note: backlog CLI cannot write decision body, so body text was filled directly in the file. game_design.md risks marked resolved, one open item added.
<!-- SECTION:NOTES:END -->
