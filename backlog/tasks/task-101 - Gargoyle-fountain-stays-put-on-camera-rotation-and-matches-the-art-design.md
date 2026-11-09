---
id: TASK-101
title: 'Gargoyle fountain: stays put on camera rotation and matches the art design'
status: Done
assignee:
  - '@claude'
created_date: '2026-11-09T09:53:00Z'
updated_date: '2026-11-09T10:26:00Z'
labels:
  - rendering
  - art
  - bug
dependencies: []
priority: high
ordinal: 107000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The gargoyle fountain (G) is one flat Y-billboard of ASCII art standing on its footprint centre. When the camera orbits, the drawn basin swims against the floor cells it occupies and the whole prop reads as a cardboard cutout. It also looks nothing like the concept (docs/art: a dark winged gargoyle bust with glowing red eyes pouring luminous water into a square stone basin, all made of fine glyphs). It must stay potato-friendly (Compatibility renderer, 30+ FPS on HD 4000 class GPUs): pre-baked art, no runtime raymarching or extra render passes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The basin is anchored to the footprint cells and does not drift against the floor at any camera yaw
- [x] #2 The statue keeps its place over the basin centre at any camera yaw and turns with the camera (pre-baked view angles)
- [x] #3 The look follows the concept: dark winged bust, glowing red eyes, luminous water falling into a glowing basin
- [x] #4 Runtime cost stays in the potato budget (no per-frame text rebuilds beyond the animated layer, a handful of draw calls per fountain)
- [x] #5 Reveal, memory tint, destruction and restore still work; existing large-object tests pass
- [x] #6 Leftover polish ideas are recorded in a 'Polishing UI' task
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Basin as real geometry fitted to the footprint (FountainBasin + shaders/fountain_basin.gdshader). 2. Statue modelled as an SDF in tools/bake_gargoyle_views.gd, ray-marched offline from 16 yaws at the iso pitch into ASCII art + layer masks (LargeObjectViews; fine + coarse bake). 3. LargeObjectView statue mode: camera-facing labels, view picked from the camera yaw, pushed along the view ray, solid backing. 4. Iterate with tools/capture_gargoyle.gd captures and an independent critique. 5. Tests, docs, Polishing UI ticket.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Rounds: 1 basin+statue wired (statue invisible: dark palette, thick outline, floor through gaps); 2 brighter, statue always backed; 3 edge glyphs / \\ | _, LOD bake, water landing inside; 4 camera-fixed key light, contrast, ramp distinct from floor glyphs; 5 36 cols to match world glyph size, bigger head/horns, wing ribs; critique 1 (3/10 match, 4/10 readability); 6 glowing water, stone rim + cyan lip + corner posts, wide bright stream, 4-tone body, fragment removal; 7 gap-limited backing, smaller eyes; critique 2 (4.5/10, 5.5/10, blockers: backing over pool, stream); 8 statue below the water line is not drawn, splash layer, water glows from the landing point, lit silhouette edges. Round 9 ideas (floor light, darkness/fog, view crossfade, sound) need glyph_world_view.gd / glyph_world_config.gd which another session is editing: moved to TASK-103. Runtime cost per fountain: 1 basin draw (a few dozen triangles) + 7 Label3D draws; texts pre-built, swapped only on a view change; water layer re-texted at anim_fps 5. Tests: test_large_objects (new _check_statues: anchoring, sizing, LOD, basin fit, view swap on yaw), test_understanding_look (statue backing always on), test_cannon, test_narration_triggers, test_reveal pass; boot smoke clean.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The gargoyle fountain is now a statue that turns with the camera standing in a real basin. Basin: FountainBasin builds rim boxes, corner posts and a water quad fitted to the footprint, drawn by shaders/fountain_basin.gdshader (glyph stone, cyan lip, glowing animated water with ripples from the landing point), so it never drifts at any yaw. Statue: tools/bake_gargoyle_views.gd models a winged, horned, red-eyed gargoyle on a pedestal pouring water as an SDF and bakes 16 views (fine 36 cols + coarse 22 cols for small footprints) into resources/config/large_objects/gargoyle_views*.tres; LargeObjectView shows the view nearest the camera yaw on camera-facing labels anchored at the footprint centre, pushed along the view ray, with an always-on silhouette backing. Flat art stays as the fallback for defs without views. Potato cost: pre-baked texts, 8 draws per fountain, no runtime raymarch or extra passes. Follow-ups in TASK-103 (Polishing UI).
<!-- SECTION:FINAL_SUMMARY:END -->
