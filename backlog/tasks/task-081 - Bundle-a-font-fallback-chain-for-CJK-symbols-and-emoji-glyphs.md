---
id: TASK-081
title: Bundle a font fallback chain for CJK, symbols and emoji glyphs
status: To Do
assignee: []
created_date: '2026-11-08T23:17:00Z'
labels:
  - rendering
  - unicode
dependencies: []
priority: medium
type: feature
ordinal: 86000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Glyphs depend on fonts installed on the machine (SystemFont fallback). Bundle subset Noto fonts (SIL OFL) so every machine draws the same CJK, symbols and emoji (see decision-003).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A shared FontVariation / fallback chain resource used by every glyph atlas and overlay text
- [ ] #2 CJK and symbol fonts are subset to the characters the game data uses; size budget stated
- [ ] #3 Licence files shipped with the fonts
<!-- AC:END -->
