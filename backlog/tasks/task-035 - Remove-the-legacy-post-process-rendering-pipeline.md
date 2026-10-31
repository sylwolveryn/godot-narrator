---
id: TASK-035
title: Remove the legacy post-process rendering pipeline
status: Done
assignee:
  - '@claude'
created_date: '2026-10-30T22:45:00Z'
updated_date: '2026-10-31T07:47:00Z'
labels:
  - rendering
milestone: m-5
dependencies:
  - TASK-031
priority: medium
type: chore
ordinal: 36000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Once the glyph world is in the game, the superseded post-process pipeline (ascii_post, SDF atlas bake, data-encoded world materials, palette LUT, encoding test, related configs) is dead weight and a source of confusion.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Legacy post-process shaders, scripts, configs and tests are removed, and nothing references them
- [x] #2 All remaining tools/test_*.gd pass and the headless boot has zero ERROR lines
- [x] #3 docs/architecture.md describes only the glyph-world pipeline
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Trace references of legacy names (grep). 2. Migrate any live-used pieces. 3. git rm legacy shaders/scripts/configs/tools/tests. 4. Edit builders, re-run them. 5. Update docs. 6. Validate boot + all tests.

Done: removed legacy shaders/scripts/configs/tools; MapReveal map_params dropped; GlyphFxConfig morph+flicker groups dropped; docs updated.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Removed (git rm, with .uid): shaders ascii_post, world_encode, world_encoding.gdshaderinc, glyph_sdf.gdshaderinc, glyph_sdf_bake, glyph_morph; scripts/rendering ascii_post_process, ascii_config, glyph_atlas, palette_config, light_config, hazard_fx_config, material_ids; resources/config ascii_config, palette_config, light_config, hazard_fx_config, camera_top_down; tools test_encoding, test_encoding_pattern.gdshader, capture_idle, capture_morph_strip, dump_atlas, measure_perf. Migrated/edited: build_resources (no legacy saves, no top-down view), build_project_settings (only reveal_mask global; old globals removed from project.godot), MapReveal (no map_params), GlyphFxConfig (unused Morph + Flicker groups removed), comments in world_config/capture_showcase. Kept: camera_tilted.tres (used by test_camera_rig), glyph_atlas_spec, intro_wave shader, scenes/spikes. Docs: architecture.md glyph-world only; visual_direction.md annotated. Tests all PASS headless, boot 0 errors, non-headless smoke clean; progress.tres hash unchanged.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Removed the legacy full-screen post-process pipeline: 6 shaders, 7 rendering scripts, 5 configs (incl. camera_top_down), 6 tools/tests, legacy shader globals (only reveal_mask remains) and the builder code that produced them; GlyphFxConfig trimmed to the erosion/death groups the overlay uses. docs/architecture.md now describes only the glyph-world pipeline. Kept: camera_tilted.tres (test_camera_rig), glyph_atlas_spec, build_glyph_atlas, intro_wave shader, scenes/spikes/. godot-validator PASS (boot clean, all tests pass, non-headless run clean, no stale references).
<!-- SECTION:FINAL_SUMMARY:END -->
