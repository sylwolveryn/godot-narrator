---
id: TASK-067
title: Narrator and world text obfuscation by understanding
status: To Do
assignee: []
created_date: '2026-11-08T15:23:00Z'
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
- [ ] #1 Per character threshold: once understanding passes it the character is always shown correctly
- [ ] #2 Below 10% stable obfuscation, 10-30% wild spin (symbols, CJK, emoji), 30%+ near-character spin converging, 90%+ resolved
- [ ] #3 Words with unresolved characters pulse in slow waves; own lines unaffected
- [ ] #4 Tests cover the stages and the found-character rule
<!-- AC:END -->
