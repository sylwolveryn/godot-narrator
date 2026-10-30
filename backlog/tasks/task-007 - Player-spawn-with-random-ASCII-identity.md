---
id: TASK-007
title: Player spawn with random ASCII identity
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T15:30:00Z'
updated_date: '2026-10-30T16:22:00Z'
labels:
  - player
  - rendering
milestone: m-0
dependencies:
  - TASK-006
  - TASK-003
  - TASK-002
documentation:
  - docs/game_design.md
priority: high
type: feature
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The player character is the core of the M1 experience and must appear as a random, exotic ASCII-art character in the middle of the screen. The identity is random per run and must still read clearly through the ASCII shader.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A player character spawns at the center of the screen after the intro.
- [x] #2 The character's ASCII identity is chosen randomly from a data-driven set (resource or exported list).
- [x] #3 The identity is readable on screen under the ASCII shader at the chosen cell size.
- [x] #4 The identity is chosen randomly only on the very first run; later runs reuse the saved identity
- [ ] #5 Identity is stored as persistent data (read by the save task), not per-run state
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. PersistentProgress + SaveService (memory only, load/save seams for task-013). 2. IdentityPool + PlayerConfig resources. 3. Player CharacterBody3D placed at MapLoader.spawn_position on run_started, picks/reuses identity via SaveService. 4. GlyphOverlay CanvasLayer (layer 10) draws the glyph at camera.unproject_position. 5. CameraRig follows player, snaps on SignalBus.player_spawned. 6. Test + Movie Maker.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented scripts/core/{persistent_progress,save_service}.gd, scripts/player/{player,player_config,identity_pool}.gd, scripts/rendering/glyph_overlay.gd, CameraRig.snap_to_target, SignalBus.player_spawned, resources identity_pool.tres/player_config.tres. Pool of 10 glyphs verified to render (no tofu) with SystemFont [Segoe UI Symbol, Nirmala UI, ...]; dropped wide/tiny ones. Evidence: test_intro_player PASS (player at spawn_position, identity from pool, stored in progress, reused on restart and when pre-stored); screenshots scratchpad/shots_010/f00000215.png (glyph crisp at screen centre, white with black outline) and shots_007/f00000199.png.
<!-- SECTION:NOTES:END -->
