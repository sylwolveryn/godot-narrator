---
id: TASK-067
title: Narrator and world text obfuscation by understanding
status: Done
assignee: []
created_date: '2026-11-08T15:23:00Z'
updated_date: '2026-11-08T15:49:00Z'
labels:
  - narrator
  - ui
dependencies:
  - TASK-065
priority: medium
type: feature
ordinal: 69000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Narrator and world lines should be hard to read at low understanding and resolve as it grows (own lines excluded). Each character starts as a stable obfuscated stand-in, spins through wild characters from 10%, through near characters from 30%, is mostly readable at 60-70% and settles at 90%+; once a character is understood it never glitches again in any word.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Per character threshold: once understanding passes it the character is always shown correctly
- [x] #2 Below 10% stable obfuscation, 10-30% wild spin (symbols, CJK, emoji), 30%+ near-character spin converging, 90%+ resolved
- [x] #3 Words with unresolved characters pulse in slow waves; own lines unaffected
- [x] #4 Tests cover the stages and the found-character rule
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Overlay obfuscates narrator and world lines (never own) by understanding: per-character threshold 45-92% (hashed, case-insensitive) after which it is always right; <10% stable stand-ins, 10-30% wild spin (symbols, CJK, emoji with fallback fonts), 30%+ near-letter spin converging; words with unresolved characters pulse; world glitch share falls with understanding. Narrator takes understanding from SignalBus, library switches narration language on language_selected. Tests in test_narration_library (stages, found rule, own excluded); captures at 5/20/50/75/95%.
<!-- SECTION:FINAL_SUMMARY:END -->
