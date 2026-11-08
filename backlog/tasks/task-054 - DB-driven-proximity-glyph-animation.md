---
id: TASK-054
title: DB-driven proximity glyph animation
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T13:18:00Z'
updated_date: '2026-11-08T13:20:00Z'
labels:
  - rendering
  - database
dependencies:
  - TASK-046
priority: medium
type: feature
ordinal: 56000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The shimmering floor glyphs are loved, but their characters, colours and intensity are hardcoded. A glyph_anim table makes them editable and ties the intensity to the distance to the player.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Per surface type the DB defines the character cycle, a colour palette, near/far intensity, radius and speeds
- [ ] #2 Characters cycle and colours blend smoothly, more (or less, per config) intense near the player
- [ ] #3 Reloading from the god tool applies new values without restarting the game
<!-- AC:END -->
