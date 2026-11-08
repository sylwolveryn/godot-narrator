---
id: TASK-064
title: Placeholder MP3s to check override-first audio loading
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T15:03:00Z'
updated_date: '2026-11-08T15:22:00Z'
labels:
  - narrator
dependencies: []
priority: low
type: chore
ordinal: 66000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The user wants to drop real MP3s in to verify the lookup order (override folder first, bundled asset second). In the editor the override root was the project folder itself, so both locations were the same; dev runs need a separate override folder.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Dev override root is a separate folder (project/override), exported builds still use the exe folder; the missing log stays under the game root logs/
- [x] #2 Two empty MP3s exist: the override copy and the asset copy of one narrator event
- [x] #3 Audio loads from the raw file when present so swapped files work without reimport
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Dev override root = <project>/override (gdignored), export = exe folder; missing log under the game root. Raw file read first, imported resource as fallback. Empty placeholders: override/narration/event/RUN_STARTED_EN_GB.mp3 (1st) and narration/event/RUN_STARTED_EN_GB.mp3 (2nd).
<!-- SECTION:FINAL_SUMMARY:END -->
