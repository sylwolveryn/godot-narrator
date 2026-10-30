---
id: TASK-033
title: Player, hazards and items in the glyph world
status: To Do
assignee: []
created_date: '2026-10-30T22:45:00Z'
labels:
  - rendering
  - player
  - world
milestone: m-5
dependencies:
  - TASK-031
priority: high
type: feature
ordinal: 34000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The player identity glyph, items, spikes and corrupting areas need their glyph-world look: emissive glows with cheap halos, corruption breathing slowly, and erosion and death readable on the player glyph. The overlay-only presentation from the old renderer no longer fits an isometric world.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The player identity glyph stands in the iso world, readable at 1366x768, with a warm light and halo
- [ ] #2 Items, spikes and corrupting areas glow through cheap halos; halos look soft, not like flat orbs
- [ ] #3 Erosion and death stay clearly readable on the player, within the flicker limits
- [ ] #4 tools/test_hazards.gd and tools/test_intro_player.gd pass
<!-- AC:END -->
