---
id: TASK-034
title: Narration and intro in the isometric view
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T22:45:00Z'
updated_date: '2026-11-02T06:59:00Z'
labels:
  - narrator
  - ux
  - rendering
milestone: m-5
dependencies:
  - TASK-031
priority: medium
type: feature
ordinal: 35000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Narration text and the intro wave were tuned for the old top-down, post-processed screen. They must stay legible and on-mood over the new iso glyph world without hiding the player.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Narration lines are legible over the glyph world at 1366x768 and 1920x1080 and never cover the player
- [x] #2 The intro hands off into the iso glyph world without a visual pop
- [x] #3 tools/test_narrator.gd passes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Overlay per-letter eased morph with mood glow. 2. Intro easing. 3. Test + captures.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Overlay letter morph (no scramble), mood glow tints in NarratorConfig, intro easing; test_narrator extended; all tests PASS headless; boot 0 ERROR; captures at 1366x768 and 1920x1080 reviewed; measure: 30 FPS, 4.7 draw calls.
<!-- SECTION:NOTES:END -->
