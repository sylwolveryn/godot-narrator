---
id: TASK-062
title: 'Narration layers: world, own, narrator'
status: To Do
assignee:
  - '@claude'
created_date: '2026-11-08T15:03:00Z'
labels:
  - narrator
  - ui
dependencies: []
priority: high
type: feature
ordinal: 64000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
One voice is not enough: the world itself, the character's own memory and the narrator should speak differently. An event can now have a line per layer, played in the order world, own, narrator, each with its own look. All existing lines are narrator lines.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Beats have a layer (WORLD, OWN, NARRATOR; default NARRATOR); an event plays its eligible lines in the order world, own, narrator
- [ ] #2 World lines: vibrant green and purple, glitchy
- [ ] #3 Own lines: player glyph colour, words partially broken / switching based on understanding of the current language (DB player_language), light glitch
- [ ] #4 Narrator lines keep the current blue glowing look; voice files play with narrator lines
- [ ] #5 Tests cover the layer order
<!-- AC:END -->
