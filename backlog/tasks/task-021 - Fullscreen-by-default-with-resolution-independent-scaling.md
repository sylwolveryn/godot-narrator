---
id: TASK-021
title: Fullscreen by default with resolution-independent scaling
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T17:45:00Z'
updated_date: '2026-10-30T17:46:00Z'
labels:
  - rendering
  - ux
milestone: m-2
dependencies: []
priority: high
type: feature
ordinal: 24000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Playtest: the window is small and every overlay size was tuned only for 960x540. The game should open fullscreen and look the same at any resolution or aspect ratio.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The game starts fullscreen by default (value in project settings or a config resource, not code)
- [ ] #2 ASCII cell size, player glyph, narration text, intro wave and death/erosion effects scale with the window so the composition matches at 1280x720, 1920x1080 and 2560x1440 (verified by captures)
- [ ] #3 Ultrawide and 4:3 windows keep the player centred with no stretched glyphs
- [ ] #4 A key toggles fullscreen/windowed through an InputMap action
<!-- AC:END -->
