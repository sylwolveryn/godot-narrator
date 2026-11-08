---
id: TASK-048
title: Plugin-style narration file lookup with missing-file log
status: To Do
assignee: []
created_date: '2026-11-08T13:18:00Z'
labels:
  - narrator
dependencies:
  - TASK-046
priority: high
type: feature
ordinal: 50000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Players should be able to override narration text and audio by dropping files next to the game executable (a plugin system). The narration table names the text (.json) and sound (.mp3) file per event and language; the game must find them in the override root first, then in the bundled assets, and record what is missing instead of failing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Text/audio are resolved from <override root>/narration/event/<EVENT>_<LANG>.(json|mp3) first, then res://narration/event/
- [ ] #2 When neither exists, <EVENT>_<LANG>_TEXT or _AUDIO is added once to logs/missing-narrations.json (a set, no duplicates) and reported to the DB
- [ ] #3 The game still boots and narrates with the database offline (bundled seed fallback)
- [ ] #4 Each played narration increments its trigger count in the DB
<!-- AC:END -->
