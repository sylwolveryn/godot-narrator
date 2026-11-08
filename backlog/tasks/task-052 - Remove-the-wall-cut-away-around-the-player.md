---
id: TASK-052
title: Remove the wall cut-away around the player
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T13:18:00Z'
updated_date: '2026-11-08T13:46:00Z'
labels:
  - rendering
dependencies:
  - TASK-051
priority: low
type: chore
ordinal: 54000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The cut-away that dissolves walls between camera and player looks odd; with camera rotation and zoom the player can find the avatar themselves.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 No surface dissolves near the player any more
- [x] #2 Cut-away config and shader code are gone
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Removed the cut-away uniforms/code from glyph_surface.gdshader, its config fields and GlyphWorldView feed. All suites pass; captured frame shows no dissolving walls.
<!-- SECTION:FINAL_SUMMARY:END -->
