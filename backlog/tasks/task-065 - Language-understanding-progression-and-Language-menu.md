---
id: TASK-065
title: Language understanding progression and Language menu
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T15:23:00Z'
updated_date: '2026-11-08T15:49:00Z'
labels:
  - gameplay
  - database
  - narrator
dependencies: []
priority: high
type: feature
ordinal: 67000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Understanding of the selected language is the game's core progress meter. It starts at 0% English on a new game and grows with play; reaching 60% opens a new language. It drives the narration language and several presentation effects (world clarity, glyph glow, text obfuscation).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Per save: understanding per language (0..100), selected language and unlocked languages; new game = EN_GB 0%; mirrored to DB player_language
- [x] #2 Gains for the selected language: +1% per 20 tiles walked, +1% per death, +3% the first time a new type of thing is discovered
- [x] #3 In-world menu has Language: lists unlocked languages with their % and selecting one switches the narration language
- [x] #4 Opening Language with the selected language at 60%+ plays a glyph storm and unlocks the next language at 1%
- [x] #5 SignalBus announces selected-language understanding changes; tests cover gains, unlock and selection
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
LanguageProgress (only writer) + LanguageConfig; save fields language_understanding, selected_language, unlocked_languages, discovered_types, language_step_remainder; new save EN_GB 0%. Gains: +1%/20 tiles, +1%/death, +3% per first-ever cell type. DB mirror set_language_understanding on load and per whole percent. Menu item Language -> list 'English 37%' + back; selecting switches language; opening at >=60% unlocks the next language (unlock order HU_HU, ALIEN, ...) at 1% with a glyph storm. Signals: language_understanding_changed / language_selected / language_unlocked (+ request signals). Tests: test_language_progress, test_menu, test_save, god tests. Note: each opening at >=60% unlocks one more language.
<!-- SECTION:FINAL_SUMMARY:END -->
