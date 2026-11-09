---
id: TASK-098
title: 'god: new game mods - fog on/off and sight area scale'
status: To Do
assignee:
  - '@claude'
created_date: '2026-11-09T08:25:00Z'
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
- [ ] #1 The New game with mods dialog has a Fog mod (fog on or off) and a Sight area mod (percent scale of the reveal radius and player light radius, every form)
- [ ] #2 The mods reach the started game as command line user arguments only; a later Continue game runs without them; no DB row is written
- [ ] #3 Fog off shows the map without depth fog or darkness and reveals all cells; fog on forces the normal fog and darkness even on maps whose DB row turns them off
- [ ] #4 Headless tests cover argument parsing and the effect on the effective map settings
<!-- AC:END -->
