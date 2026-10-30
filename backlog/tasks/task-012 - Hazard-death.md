---
id: TASK-012
title: Hazard death
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T15:30:00Z'
updated_date: '2026-10-30T16:54:00Z'
labels:
  - world
  - core
milestone: m-0
dependencies:
  - TASK-011
  - TASK-005
documentation:
  - docs/game_design.md
priority: high
type: feature
ordinal: 12000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The M1 run must end through a hazard, which is the first real loss condition. Death is what triggers saving and restarting, so this task closes the loop of the first run.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Hazard definitions (type, damage or effect, visuals) are data-driven.
- [x] #2 Death emits a run-end signal through `SignalBus`.
- [x] #3 Death does not pause the game, and the next run starts without a menu.
- [x] #4 Spike tiles end the run when touched
- [x] #5 Corrupting glyph areas erode the character over time while inside them and end the run when erosion completes; erosion rate and threshold come from a resource
- [x] #6 Hazard types for M1 are exactly spikes and corrupting glyphs
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. HazardDefinition resource (kind, end cause, lethal_on_touch, erosion rate/threshold/recovery, tint) + hazard_spikes/hazard_corrupting .tres; MapLegend maps cell type -> definition.
2. HazardMonitor node: reads player cell each physics frame, only during PLAYING, requests end via SignalBus.run_end_requested once; erosion kept in RunState and announced via SignalBus.erosion_changed.
3. GlyphOverlay: erosion scramble/jitter/fade on player glyph; death shatter during restart delay (GlyphFxConfig).
4. Builders, tools/test_hazards.gd, visual capture autopilot.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented: HazardDefinition (+hazard_spikes/hazard_corrupting .tres, referenced via MapLegend.hazards), HazardMonitor (cell lookup per physics frame, PLAYING only, one-shot per run, lethal when unrevealed), SignalBus erosion_changed/hazard_lethal, RunState.erosion, GlyphOverlay erosion scramble/jitter/fade/tint + death shatter (GlyphFxConfig). Evidence: tools/test_hazards.gd PASS (no fire in INTRO, spike kills once while hidden, no double fire in DYING, tree not paused, auto restart, erosion partial/recovers/kills, no leak); all tools/test_*.gd PASS; boot --quit-after 60 zero ERROR. Visual: Movie Maker capture via tools/capture_hazards.gd; erosion scramble frames f00000135..f00000175, death shatter f00000209..f00000245, restart f00000256 in C:/Users/SYLWOL~1/AppData/Local/Temp/claude/E--git-godot-narrator/9bf6ff4a-2b4c-4f5c-8bbc-2621e15c92c1/scratchpad/shots_012 (sheets sheet_erosion.png, sheet_death.png).
<!-- SECTION:NOTES:END -->
