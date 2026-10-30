---
id: TASK-010
title: Handcrafted map loading
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T15:30:00Z'
updated_date: '2026-10-30T16:22:00Z'
labels:
  - world
milestone: m-0
dependencies:
  - TASK-002
documentation:
  - docs/game_design.md
priority: high
type: feature
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The M1 world is one handmade map saved in a file, with no procedural generation. Loading from a file establishes the content pipeline the later world editor will use.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The M1 map is loaded from a file in the project data folder.
- [x] #2 Map data (walls, items, hazards, spawn point) comes from the file, not from code.
- [x] #3 Loading the map does not require editing a `.tscn` or `.tres` file as raw text.
- [ ] #4 A map file with a missing or malformed entry produces a logged error and does not crash the game.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. MapLegend/MapData/MapCell/MapLoader (parse text, build merged wall/floor runs, item/hazard Area3D placeholders). 2. Author data/maps/m1_awakening.txt. 3. Builders place MapLoader under World, replacing placeholders. 4. tools/test_map_loader.gd for malformed input. 5. Visual check via Movie Maker.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented scripts/world/{map_legend,map_data,map_cell,map_loader}.gd, resources/config/map_legend.tres, data/maps/m1_awakening.txt (40x23, spawn (20,12), 8 items, spike strips, 3 corrupting patches, nothing lethal near spawn). Walls merged per horizontal run (StaticBody3D), floors per run, items/spikes/corrupt are MapCell (Area3D) with cell_type + groups map_items/map_spikes/map_corrupt/map_hazards. Malformed input (unknown char, missing @, extra @, ragged rows, empty, missing file) logs warning/error and never crashes. Evidence: tools/test_map_loader.gd PASS; boot --quit-after 60 zero ERROR; screenshot scratchpad/shots_010/f00000215.png shows walls/pillars/corridors through the ASCII shader. Tuning: default clear colour set black in project.godot (void was rendering as '=' grey), world colours tinted + AsciiConfig.scene_color_mix 0.8.
<!-- SECTION:NOTES:END -->
