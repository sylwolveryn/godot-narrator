---
id: TASK-014
title: Narrator text system and SFX trigger
status: To Do
assignee: []
created_date: '2026-10-30T15:30:00Z'
labels:
  - narrator
  - audio
  - rendering
milestone: m-0
dependencies:
  - TASK-004
  - TASK-003
  - TASK-001
documentation:
  - docs/game_design.md
priority: medium
type: feature
ordinal: 14000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The narrator is the story's voice in M1 and must show morphing ASCII text with ambient sound. The beats must be triggered by events or time, not hard-coded into scenes, so later beats can be added as data.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Narration text assembles on screen as morphing ASCII text using the presentation approach chosen by the spike.
- [ ] #2 Ambient SFX plays alongside narration when a beat is triggered.
- [ ] #3 Narration beats are data-driven (resource or exported list) and each beat specifies its trigger (event or time).
- [ ] #4 Each M1 narration beat defined in the narrator content triggers at its configured point and plays its text and SFX once per run unless its data says otherwise.
<!-- AC:END -->
