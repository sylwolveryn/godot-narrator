---
id: TASK-085
title: Move the remaining glyph sets from resources into the DB
status: To Do
assignee: []
created_date: '2026-11-08T23:17:00Z'
labels:
  - db
  - rendering
dependencies: []
priority: medium
type: feature
ordinal: 90000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Glyph sets still live in .tres configs: teleport frame and broken chars, cannon art and ball chars, enemy and remains glyphs, menu frame glyphs, storm glyphs, identity pool. Like glyph_ramp they should come from the DB so god can change them live.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each glyph set has a DB row and is applied on DB reload
- [ ] #2 Seed and god table list updated
<!-- AC:END -->
