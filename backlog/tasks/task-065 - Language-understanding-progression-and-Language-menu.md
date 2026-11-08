---
id: TASK-065
title: Language understanding progression and Language menu
status: To Do
assignee: []
created_date: '2026-11-08T15:23:00Z'
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
- [ ] #1 Per save: understanding per language (0..100), selected language and unlocked languages; new game = EN_GB 0%; mirrored to DB player_language
- [ ] #2 Gains for the selected language: +1% per 20 tiles walked, +1% per death, +3% the first time a new type of thing is discovered
- [ ] #3 In-world menu has Language: lists unlocked languages with their % and selecting one switches the narration language
- [ ] #4 Opening Language with the selected language at 60%+ plays a glyph storm and unlocks the next language at 1%
- [ ] #5 SignalBus announces selected-language understanding changes; tests cover gains, unlock and selection
<!-- AC:END -->
