---
id: TASK-097
title: 'god: new game mod - all forms unlocked'
status: To Do
assignee:
  - '@claude'
created_date: '2026-11-09T08:25:00Z'
labels: []
dependencies: []
priority: medium
type: feature
ordinal: 102000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Testing the forms needs many runs (deaths, a fully discovered map, teleports) before one, many and brain can be switched. The god launcher's New game with mods should start a game where every form is available. It is a save-only tweak of the fresh game, never a DB change.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The New game with mods dialog has an All forms mod (on/off)
- [ ] #2 With it on, the fresh save has the many (grown) and brain forms unlocked plus the menu, so single, grown and brain can be switched
- [ ] #3 No DB table is changed
- [ ] #4 god Python tests and a headless Godot test cover the mod
<!-- AC:END -->
