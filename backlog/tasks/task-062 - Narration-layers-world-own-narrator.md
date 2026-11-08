---
id: TASK-062
title: 'Narration layers: world, own, narrator'
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T15:03:00Z'
updated_date: '2026-11-08T15:22:00Z'
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
- [x] #1 Beats have a layer (WORLD, OWN, NARRATOR; default NARRATOR); an event plays its eligible lines in the order world, own, narrator
- [x] #2 World lines: vibrant green and purple, glitchy
- [x] #3 Own lines: player glyph colour, words partially broken / switching based on understanding of the current language (DB player_language), light glitch
- [x] #4 Narrator lines keep the current blue glowing look; voice files play with narrator lines
- [x] #5 Tests cover the layer order
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
NarrationBeat.layer (WORLD/OWN/NARRATOR, default NARRATOR; all existing beats NARRATOR). Narrator picks the earliest layer, chains later-layer lines of the same event (no silence gap, dropped on death preempt); voice only with narrator lines. Overlay looks: world green/purple sweep + split ghosts + glitch ticks; own = player glyph colour, not-understood words switch with scrambled glyphs (share 1 - player_language understanding) + light glitch; narrator = old look with glow pulled to blue. Verified: test_narration_library (order, no-gap chain, once, looks), test_narrator, rendered frames.
<!-- SECTION:FINAL_SUMMARY:END -->
