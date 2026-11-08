---
id: TASK-077
title: >-
  Items menu, consumption counts, many-form cannon, language max, god palette
  editor
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T21:03:00Z'
labels:
  - gameplay
  - menu
  - tools
  - db
dependencies: []
priority: medium
type: feature
ordinal: 82000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Count consumed things; an Items menu entry from the first dirt or diamond, announced by a rainbow pulse from the player; many-form cannon doubles its rate and fires 1-6 balls with own/narrator lines; player_language.max top limit; palette editor in god.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Consumed dirt and diamonds are counted per kind in the save (PersistentProgress.consumed) and in the DB (player_consumed)
- [ ] #2 The Items menu entry appears with the first dirt eaten or diamond picked up and lists the counts
- [ ] #3 While a menu item is new, a rainbow ring of about 0.3 tile pulses from the player every 5 s until the menu shows it
- [ ] #4 In the many form, cannon autofire is twice as fast and every shot launches 1-6 balls; first time: own 'Am I the weapon, or am I the solution?' then narrator 'Thousand year question'
- [ ] #5 player_language.max caps understanding when >= 0; a value over it is brought down to it
- [ ] #6 god opens a palette editor for colour cells: see, add, change, remove, reorder, hex
<!-- AC:END -->
