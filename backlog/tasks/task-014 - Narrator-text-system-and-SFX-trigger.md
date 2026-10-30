---
id: TASK-014
title: Narrator text system and SFX trigger
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T15:30:00Z'
updated_date: '2026-10-30T17:13:00Z'
labels:
  - narrator
  - audio
  - rendering
milestone: m-0
dependencies:
  - TASK-004
  - TASK-003
  - TASK-001
documentation:
  - docs/game_design.md
priority: medium
type: feature
ordinal: 14000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The narrator is the story's voice in M1 and must show morphing ASCII text with ambient sound. The beats must be triggered by events or time, not hard-coded into scenes, so later beats can be added as data.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Narration text assembles on screen as morphing ASCII text using the presentation approach chosen by the spike.
- [ ] #2 Ambient SFX plays alongside narration when a beat is triggered.
- [ ] #3 Narration beats are data-driven (resource or exported list) and each beat specifies its trigger (event or time).
- [ ] #4 Narration progress persists: a beat already heard does not repeat in later runs, and new beats unlock by run or death count
- [ ] #5 Beats can be gated by run count so tone can shift from cryptic to clearer over runs
- [ ] #6 M1 beats hint at contradicting origins (e.g. hero vs villain, alien, AI, demonic, angelic) and never state one answer
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. NarrationBeat/NarratorConfig/NarrationMood resources; beats built from data/narration/m1_beats.json by tools/build_narration.gd. 2. Narrator (logic, signals up), NarrationOverlay (layer 25 morph text), NarrationSfx (procedural moods). 3. Events via SignalBus.narration_event from Player/MapReveal/HazardMonitor; run/death derived by narrator. 4. SaveService: beat_heard persistence + save on quit. 5. tools/test_narrator.gd + capture_narrator.gd visual/audio check.
<!-- SECTION:PLAN:END -->
