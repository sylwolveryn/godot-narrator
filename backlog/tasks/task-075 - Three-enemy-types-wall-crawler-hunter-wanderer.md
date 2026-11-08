---
id: TASK-075
title: 'Three enemy types: wall crawler, hunter, wanderer'
status: To Do
assignee:
  - '@claude'
created_date: '2026-11-08T17:10:00Z'
labels:
  - gameplay
  - world
  - rendering
  - database
dependencies:
  - TASK-073
priority: high
type: feature
ordinal: 77000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
First enemies. Each type moves its own way: the crawler always follows a wall (left-hand or right-hand variant), the hunter follows the player, the wanderer moves randomly. They are destructible by cannon balls through the generic destructible interface.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Map chars: L = crawler following the left wall, R = crawler following the right wall, H = hunter, W = wanderer; each drawn as its own ASCII glyph creature
- [ ] #2 Movement styles behave as named on the grid (wall following never loses its wall, hunter paths around obstacles to the player, wanderer picks random free directions)
- [ ] #3 Touching the player ends the run (cause per enemy type, death narration event); cannon balls destroy enemies
- [ ] #4 Enemy speeds and lethality per type in a DB table with defaults; tests cover each movement rule, contact death and destruction
<!-- AC:END -->
