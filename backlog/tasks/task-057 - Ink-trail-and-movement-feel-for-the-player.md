---
id: TASK-057
title: Ink trail and movement feel for the player
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T14:07:00Z'
updated_date: '2026-11-08T14:29:00Z'
labels:
  - rendering
  - database
dependencies:
  - TASK-056
priority: medium
type: feature
ordinal: 59000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Movement reads like a 1990s sprite slide. A short ink-like glyph trail that fades quickly, plus a slight lean/stretch while accelerating, makes motion felt. The trail is DB-configurable.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Moving leaves small ink glyphs behind that fade out within a configurable time; one draw call, no per-frame allocation
- [x] #2 The avatar leans/stretches subtly with acceleration and settles when still
- [x] #3 Trail and feel values come from avatar_fx and apply on reload
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
InkTrailView: ring buffer MultiMesh (one draw call) of flat ink glyphs dropped every trail_spacing, fading/spreading in shaders/ink_trail.gdshader from a per-frame clock uniform. Lean into motion and stretch/squash with acceleration via the actor transform's Y column. All values in DB avatar_fx (live: SQL UPDATE + god Reload). Verified: tools/test_avatar_fx.gd (stretch on start, lean while moving, squash on braking, settle, drops only while moving, reload) and captured frames; trail made larger/brighter after the first look.
<!-- SECTION:FINAL_SUMMARY:END -->
