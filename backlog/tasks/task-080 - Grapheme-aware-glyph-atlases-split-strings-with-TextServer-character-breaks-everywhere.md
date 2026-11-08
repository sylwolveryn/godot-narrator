---
id: TASK-080
title: >-
  Grapheme-aware glyph atlases: split strings with TextServer character breaks
  everywhere
status: To Do
assignee: []
created_date: '2026-11-08T23:17:00Z'
labels:
  - rendering
  - unicode
dependencies: []
priority: medium
type: feature
ordinal: 85000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Strings are turned into glyphs per code point (unicode_at, substr, length), which splits emoji with VS16, ZWJ sequences, flags and combining marks (see decision-003). Every atlas builder and glyph list must split with TextServer.string_get_character_breaks and draw clusters with Font.draw_string.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 glyph_anim chars, menu, player identity, entity, storm, teleport, cannon and enemy glyph code split strings into grapheme clusters
- [ ] #2 Limits like GlyphAnimConfig.max_chars count graphemes
- [ ] #3 A test draws a ZWJ emoji, a flag and a combining mark as one cell each
<!-- AC:END -->
