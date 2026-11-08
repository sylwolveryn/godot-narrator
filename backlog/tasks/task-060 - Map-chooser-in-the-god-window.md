---
id: TASK-060
title: Map chooser in the god window
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T14:07:00Z'
updated_date: '2026-11-08T14:29:00Z'
labels:
  - tools
dependencies:
  - TASK-059
priority: medium
type: feature
ordinal: 62000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Testing a second map needs a way to start the game on it without editing the main scene.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 God window lists data/maps/*.txt and starts/continues the game on the chosen map
- [x] #2 The game takes the map from a command-line user argument and falls back to the scene's map
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
MapLoader.map_path_from_args (--map=<name|path> user arg, fallback to map_path, warning when missing). god: Map combobox, core.list_maps/game_args/settings (god/settings.json, gitignored), GameController.map_name; 61 python tests pass.
<!-- SECTION:NOTES:END -->
