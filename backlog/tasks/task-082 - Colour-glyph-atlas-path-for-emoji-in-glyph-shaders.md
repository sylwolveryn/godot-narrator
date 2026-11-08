---
id: TASK-082
title: Colour glyph atlas path for emoji in glyph shaders
status: To Do
assignee: []
created_date: '2026-11-08T23:17:00Z'
labels:
  - rendering
  - unicode
dependencies: []
priority: low
type: feature
ordinal: 87000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Glyph shaders use the atlas as a white mask tinted by palettes, so colour emoji draw as silhouettes. Decide and build an optional colour path (CBDT/SVG fonts; COLR is reported unsupported) per surface or glyph set (see decision-003).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A per-glyph-set switch: tinted mask or own colours
- [ ] #2 Works in the Compatibility renderer within the 30 FPS budget
<!-- AC:END -->
