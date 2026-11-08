---
id: TASK-048
title: Plugin-style narration file lookup with missing-file log
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T13:18:00Z'
updated_date: '2026-11-08T13:46:00Z'
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
- [x] #1 Text/audio are resolved from <override root>/narration/event/<EVENT>_<LANG>.(json|mp3) first, then res://narration/event/
- [x] #2 When neither exists, <EVENT>_<LANG>_TEXT or _AUDIO is added once to logs/missing-narrations.json (a set, no duplicates) and reported to the DB
- [x] #3 The game still boots and narrates with the database offline (bundled seed fallback)
- [x] #4 Each played narration increments its trigger count in the DB
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
New GameDatabase node (scripts/data/) talks to SpacetimeDB over plain HTTP (token, SQL reads, reducer calls), starts from the bundled seed data/db/seed.json so it works offline, and reloads when config_version changes. NarrationLibrary resolves narration/event/<EVENT>_<LANG>.json/.mp3 from the override root (exe folder in exports, project folder in the editor, or NarrationLibraryConfig.override_root) before res://, logs missing files once to logs/missing-narrations.json and the DB missing_narration table, and counts every triggered event via narration_triggered. Verified: tools/test_narration_library.gd (override precedence, asset fallback, dedup set, restart persistence, DB paths, SQL parsing) and a live boot against the local server (trigger counts, missing rows, log file). Tests disable the DB through Support.isolate_data. Export note: add narration/*.json and data/db/seed.json to the export include filter.
<!-- SECTION:FINAL_SUMMARY:END -->
