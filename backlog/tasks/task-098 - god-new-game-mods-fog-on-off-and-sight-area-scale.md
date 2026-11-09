---
id: TASK-098
title: 'god: new game mods - fog on/off and sight area scale'
status: Done
assignee:
  - '@claude'
created_date: '2026-11-09T08:25:00Z'
updated_date: '2026-11-09T09:10:00Z'
labels: []
dependencies: []
priority: medium
type: feature
ordinal: 103000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
For testing maps and forms it helps to start a run with the fog of war off (or forced on) and with a bigger or smaller visible area for every form. These are run-only tweaks passed to the started game; they must not change the DB map_settings rows.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The New game with mods dialog has a Fog mod (fog on or off) and a Sight area mod (percent scale of the reveal radius and player light radius, every form)
- [x] #2 The mods reach the started game as command line user arguments only; a later Continue game runs without them; no DB row is written
- [x] #3 Fog off shows the map without depth fog or darkness and reveals all cells; fog on forces the normal fog and darkness even on maps whose DB row turns them off
- [x] #4 Headless tests cover argument parsing and the effect on the effective map settings
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. scripts/core/run_mods.gd (RunMods): parses --fog=0|1 and --sight=<percent> from the user args.
2. MapSettings.resolve applies the fog override to a copy of the row; MapReveal.area_scale and GlyphWorldView.player_light_radius apply the sight scale.
3. god: mods get a target (save tool vs game launch); Fog and Sight mods are game args passed only to the modded start; toggle field as a checkbox.
4. Tests: test_map_settings run mods section, god test_mods.
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fog (checkbox) and Sight area (percent) mods, off by default, are passed only to the modded game start as --fog / --sight user args (RunMods); Continue runs without them and no DB row is written. Fog off = no depth fog, full light, reveal_all (the reveal is remembered in the save, like god's Reveal map); fog on forces fog and darkness. Sight scales reveal radius and player light for every form. Verified: test_map_settings run-mods section, god unittest.
<!-- SECTION:FINAL_SUMMARY:END -->
