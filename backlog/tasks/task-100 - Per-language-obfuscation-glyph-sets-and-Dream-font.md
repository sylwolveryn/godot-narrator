---
id: TASK-100
title: Per-language obfuscation glyph sets and Dream font
status: Done
assignee:
  - '@claude'
created_date: '2026-11-09T09:53:00Z'
updated_date: '2026-11-09T10:02:00Z'
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
- [x] #1 language_def has static_glyphs, wild_glyphs, foreign_chance and font columns (DB module + seed.json), empty = NarratorConfig defaults
- [x] #2 Narration obfuscation stand-ins come from the selected language's pools; a foreign_chance share comes from the shared foreign pool
- [x] #3 DREAM stand-ins are drawn with the bundled Dream font (assets/fonts/dream, OFL licence included)
- [x] #4 Live reload: editing a language_def row in god changes the stand-ins without restart
- [x] #5 Test covers per-language pool selection and foreign chance
- [x] #6 docs/game_elements.md Language section documents glyph pools, roll-over stages and the font
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
DB: 4 columns appended with #[default] so the local DB migrated in place (no data wipe); seed_defaults fills old rows whose pools are all empty. Font: no OFL 'alien' font exists (alien fonts found are non-commercial), so the Dream script uses Noto Sans Vai (OFL) whose loops/coils/dots match the concept art. Overlay shrinks stand-ins wider than the real letter (min NarratorConfig.obf_fit_min_scale 0.6) - CJK/Hangul overlapped badly before. Visual check via tools/capture_language_glyphs.gd (all 9 languages at 5% and 20%).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Each language_def row now carries its own obfuscation pools (static_glyphs, wild_glyphs), a foreign_chance share from a shared other-alphabet pool, and an optional font. Seeded: Cyrillic for RU_RU, kanji / kana for Japanese, heavy kana+kanji+Hangul+Arabic+symbols+emoji mix for MATRIX, Noto Sans Vai coils for DREAM (bundled with OFL). LanguageGlyphs resolves a row (empty = NarratorConfig defaults); Narrator picks it per beat so god edits apply live. Overlay draws native stand-ins with the language font and fits wide glyphs to the letter width. Tests: test_language_glyphs (new), test_narration_library, test_narrator, god unittests pass; boot smoke clean; screenshots checked. Docs: game_elements.md Language section, database/README.md.
<!-- SECTION:FINAL_SUMMARY:END -->
