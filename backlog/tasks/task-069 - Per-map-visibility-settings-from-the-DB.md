---
id: TASK-069
title: Per-map visibility settings from the DB
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T16:44:00Z'
updated_date: '2026-11-08T16:45:00Z'
labels:
  - world
  - database
  - rendering
dependencies: []
priority: high
type: feature
ordinal: 71000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Maps need different visibility rules: the new dirt map is fully revealed with no fog, while the existing maps keep fog, a limited sight radius and dark surroundings. These rules move to a DB table per map, with today's behaviour as the fallback when a map has no row.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 DB table map_settings (one row per map id) holds reveal/fog/sight/light settings; editable in the god window grid
- [ ] #2 A map without a row behaves exactly as today (fog on, reveal radius with line of sight, darkness and memory look outside the light)
- [ ] #3 A map can start fully revealed with no fog/darkness so everything is visible all the time
- [ ] #4 Settings are applied when the map loads and on a DB reload; tests cover default and override
<!-- AC:END -->
