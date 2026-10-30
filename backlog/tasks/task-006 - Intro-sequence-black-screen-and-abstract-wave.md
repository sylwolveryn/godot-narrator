---
id: TASK-006
title: 'Intro sequence: black screen and abstract wave'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T15:30:00Z'
updated_date: '2026-10-30T16:22:00Z'
labels:
  - ux
  - rendering
milestone: m-0
dependencies:
  - TASK-003
documentation:
  - docs/game_design.md
priority: medium
type: feature
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The first moment of the game sets the mood and shows the ASCII identity before the player does anything. The intro needs to play on a black screen with an abstract wave effect, then hand off to the spawn step.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 On launch the screen is black, then an abstract wave effect plays.
- [x] #2 The intro ends automatically and hands off to the spawn step without a pause or menu.
- [x] #3 Intro timings are exported vars or `.tres` values.
- [ ] #4 Input during the intro does not break the sequence.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. IntroConfig resource + shaders/intro_wave.gdshader (halftone dot wave, black veil). 2. IntroSequence CanvasLayer (layer 20, input ignored) tween: black hold, wave in, hold, hand off via SignalBus.intro_finished while veil+wave dissolve. 3. RunManager starts run on intro_finished; RunConfig.intro_on_restart (default false) replays lite intro on restart. 4. tools/test_intro_player.gd. 5. Movie Maker check.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented scripts/ui/{intro_config,intro_sequence}.gd, shaders/intro_wave.gdshader, SignalBus intro_requested/intro_finished, RunManager hand-off, resources/config/intro_config.tres. Evidence: tools/test_intro_player.gd PASS (spams key+mouse events during intro; intro still hands off to exactly one run; default restart emits no intro_requested; intro_on_restart=true plays lite intro then run 2). Screenshots scratchpad/shots_010/f00000012.png (black), f00000055/090 (wave), f00000120/140 (dissolve into world). Wave layer is above the ASCII layer so it stays crisp.
<!-- SECTION:NOTES:END -->
