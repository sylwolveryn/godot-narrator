---
id: TASK-057
title: Ink trail and movement feel for the player
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T14:07:00Z'
updated_date: '2026-11-08T14:07:00Z'
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
- [ ] #1 Moving leaves small ink glyphs behind that fade out within a configurable time; one draw call, no per-frame allocation
- [ ] #2 The avatar leans/stretches subtly with acceleration and settles when still
- [ ] #3 Trail and feel values come from avatar_fx and apply on reload
<!-- AC:END -->
