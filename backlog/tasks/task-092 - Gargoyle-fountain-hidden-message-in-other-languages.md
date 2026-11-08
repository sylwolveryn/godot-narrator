---
id: TASK-092
title: Gargoyle fountain hidden message in other languages
status: Done
assignee: []
created_date: '2026-11-08T23:54:00Z'
updated_date: '2026-11-08T23:59:00Z'
labels:
  - narration
dependencies: []
priority: low
type: feature
ordinal: 97000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Near the gargoyle fountain, with a language other than English selected, a line hints at a hidden message. With DREAM selected the line is the message itself.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Near the fountain with a non-English, non-DREAM language: 'There is a hidden message, you haven't seen it before. Is this just a hallucination, a dream?'
- [x] #2 With DREAM: 'under me, you will found a secret lair. Do not awaken the beast! Let it sleep.'
- [x] #3 Nothing near the fountain in English
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
FountainWhisper node (scripts/world/fountain_whisper.gd, in main via build_main_scene): within reach_cells (2) of a standing gargoyle, once per fountain per run; event by selected language: DREAM -> FOUNTAIN_SECRET (world line, text file DREAM), EN_GB silent, others -> FOUNTAIN_WHISPER (narrator line, text files for the 7 other languages). test_narration_triggers PASS.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Gargoyle fountains whisper a hidden-message hint in non-English languages and reveal the secret in DREAM.
<!-- SECTION:FINAL_SUMMARY:END -->
