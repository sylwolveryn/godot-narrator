---
id: TASK-100
title: Per-language obfuscation glyph sets and Dream font
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-09T09:53:00Z'
labels:
  - narration
  - language
dependencies: []
references:
  - docs/art/languages/dreamConcetionArt.png
priority: medium
type: feature
ordinal: 106000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Narration obfuscation (task-067) uses one global stand-in set for every language. Give each language_def row its own glyph pools so the look matches the selected language: Cyrillic for RU_RU, kana/kanji for Japanese, Matrix = heavy mix of symbols, emoji, CJK, Hangul and Arabic, Dream = an abstract alien-looking script drawn with a bundled font (Noto Sans Vai, OFL) inspired by docs/art/languages/dreamConcetionArt.png. Other alphabets appear only with a small per-language chance.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 language_def has static_glyphs, wild_glyphs, foreign_chance and font columns (DB module + seed.json), empty = NarratorConfig defaults
- [ ] #2 Narration obfuscation stand-ins come from the selected language's pools; a foreign_chance share comes from the shared foreign pool
- [ ] #3 DREAM stand-ins are drawn with the bundled Dream font (assets/fonts/dream, OFL licence included)
- [ ] #4 Live reload: editing a language_def row in god changes the stand-ins without restart
- [ ] #5 Test covers per-language pool selection and foreign chance
- [ ] #6 docs/game_elements.md Language section documents glyph pools, roll-over stages and the font
<!-- AC:END -->
