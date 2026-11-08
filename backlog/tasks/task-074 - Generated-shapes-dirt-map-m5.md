---
id: TASK-074
title: Generated-shapes dirt map (m5)
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T17:10:00Z'
updated_date: '2026-11-08T18:55:00Z'
labels:
  - world
  - tools
dependencies:
  - TASK-071
priority: medium
type: feature
ordinal: 76000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A copy of the 200x200 dirt field with mathematically generated floor routes carved into the dirt (golden-ratio spiral, concentric circles, and similar shapes), to give the enemies and the player structured tunnels.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 data/maps/m5_shapes.txt: 200x200 like m4, with floor routes carved from generated shapes (golden spiral, concentric rings, at least two more such as a Lissajous curve or rose curve, radial spokes) connected to the centre spawn
- [ ] #2 The map is produced by a reproducible generator script in tools/ (parameters in the script header), rerunnable
- [ ] #3 Enemies of all three types placed on the routes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. tools/generate_shapes_map.py: m4 copy + carved golden spiral, rings, rose, Lissajous, spokes, centre plaza; connectivity pass; enemies L/R/H/W, 2 cannons, black holes O
2. data/maps/m5_shapes.txt, default map settings (fog)
3. Load/perf check in tools/test_enemies.gd / capture
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
tools/generate_shapes_map.py (seed 5, params in header: plaza r5.5, golden spiral a=3 to r96 w2, rings 18/32/47/62/78/92 widths 1/2, rose r60 k3, Lissajous 86 3:2 phase pi/2, 8 spokes 18-92; diagonal steps carve the corner so routes are 4-connected; connectivity pass joins loose components). data/maps/m5_shapes.txt: 7749 walkable cells all connected to @ (100,100); 6 L, 6 R (on rings, >=25 from spawn), 6 H (>=55), 8 W (>=22), 2 O (>=40), 2 C at (97,98) and (103,102). No map_settings row: default fog look. Check: tools/test_shapes_map.gd (structure, connectivity, load ~3 s, per-frame cost).
<!-- SECTION:NOTES:END -->
