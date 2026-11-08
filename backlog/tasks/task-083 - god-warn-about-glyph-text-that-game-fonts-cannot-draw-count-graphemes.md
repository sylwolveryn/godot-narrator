---
id: TASK-083
title: 'god: warn about glyph text that game fonts cannot draw, count graphemes'
status: To Do
assignee: []
created_date: '2026-11-08T23:17:00Z'
labels:
  - tools
  - unicode
dependencies: []
priority: low
type: feature
ordinal: 88000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When a DB text that becomes glyphs (glyph_ramp, glyph_anim chars, ...) is edited in god, warn about characters the game fonts cannot draw and show the length in graphemes (Python: regex \X).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 god shows grapheme count and a warning for missing glyphs on edit
- [ ] #2 Unit tests for ZWJ emoji, flags, combining marks
<!-- AC:END -->
