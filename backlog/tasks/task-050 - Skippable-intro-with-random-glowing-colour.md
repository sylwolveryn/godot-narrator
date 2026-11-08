---
id: TASK-050
title: Skippable intro with random glowing colour
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T13:18:00Z'
updated_date: '2026-11-08T13:46:00Z'
labels:
  - ui
dependencies: []
priority: medium
type: enhancement
ordinal: 52000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Watching the full intro on every launch is tiresome, and the wave always has the same colour.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Esc, Space or a mouse click during the intro skips it once the world is loaded and playable
- [x] #2 Each intro picks a random wave colour and the wave has a glow
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Intro skips on intro_skip (Esc, Space, mouse buttons, pad A/Start); input is consumed so it never reaches menu/movement; hand-off happens at once and the veil dissolves over skip_dissolve_seconds. Random HSV wave colour per play and a single-pass glow halo in intro_wave.gdshader. Verified by tools/test_intro_player.gd and Movie Maker frames.
<!-- SECTION:FINAL_SUMMARY:END -->
