---
id: TASK-004
title: 'Spike: narration and menu overlay vs. ASCII shader'
status: To Do
assignee: []
created_date: '2026-10-30T15:30:00Z'
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
- [ ] #1 A written decision is recorded as a Backlog decision (`backlog decision create`) choosing overlay bypass or shader-safe text, or a documented hybrid.
- [ ] #2 A throwaway prototype shows a line of text readable on top of the shader output using the chosen approach.
- [ ] #3 The decision states how the character identity from the shader cell size question is affected, or lists it as an open item.
- [ ] #4 Open items are added to `docs/game_design.md` Open Questions.
<!-- AC:END -->
