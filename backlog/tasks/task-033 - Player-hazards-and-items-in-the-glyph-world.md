---
id: TASK-033
title: Player, hazards and items in the glyph world
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T22:45:00Z'
updated_date: '2026-10-31T09:02:00Z'
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
- [x] #1 The player identity glyph stands in the iso world, readable at 1366x768, with a warm light and halo
- [x] #2 Items, spikes and corrupting areas glow through cheap halos; halos look soft, not like flat orbs
- [x] #3 Erosion and death stay clearly readable on the player, within the flicker limits
- [x] #4 tools/test_hazards.gd and tools/test_intro_player.gd pass
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Player glyph: runtime glyph texture atlas (font-rendered) + billboard quad MultiMesh-less node in world with additive halo. 2. Halo MultiMesh/batched mesh for items/spikes/corruption, reveal-aware, breathing. 3. Erosion shader params on in-world glyph; death fragments quad pool. 4. Remove overlay player glyph. 5. Retune glyph_world_config readability. 6. Tests, captures, perf, docs.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
IMPLEMENTED (not committed). New: scripts/rendering/{player_glyph_view,glyph_halo_field}.gd, shaders/{glyph_actor.gdshader,glyph_halo.gdshader,glyph_halo.gdshaderinc}, tools/test_player_glyph.gd. Changed: glyph_fx_config, glyph_world_config (halo group + readability retune: ambient 0.30->0.46, memory_dim .35->.45, edge_gain 1.8->2.2, edge_ambient .12->.24, wall_base_dark .6->.78, seam_dim .45->.62, falloff_sharp .5->.3, depth_ambient_min .5->.72, fog .25->.15), player_config (overlay font_size/outline removed), main.tscn via build_main_scene, capture_hazards/capture_glyph_world schedules, docs/architecture.md. Removed GlyphOverlay. EVIDENCE: sheets C:/s33 (= scratchpad) t033_readability_{1366,1920}.png (before/after), t033_player_1366.png, t033_hazards_1920.png, t033_haz_a.png. PERF GTX1060 --max-fps 30: 1366x768 opening draws 4.2 prims 3453 GPU 0.46ms, worst draws 4.0 GPU 1.03ms; 1920x1061 opening GPU 0.57, worst 0.60; 30 FPS. Tests: all tools/test_*.gd PASS incl. new test_player_glyph; boot 0 ERROR; progress.tres hash unchanged. Unresolved: tuned by eye, not run on real low-end HW; unused task-025 fields (erosion_tint, death_world_dim, death_dim_time, spike_death_flash) remain in GlyphFxConfig.
<!-- SECTION:NOTES:END -->
