---
id: TASK-019
title: Small-object pushing for the multi-glyph entity
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T15:42:00Z'
updated_date: '2026-11-02T07:21:00Z'
labels:
  - player
  - world
milestone: m-1
dependencies:
  - TASK-017
documentation:
  - docs/game_design.md
priority: medium
type: feature
ordinal: 19000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The grown entity must feel meaningfully different: it can move small objects, which the single-glyph form cannot do during the first three runs. This opens new routes and puzzles in handcrafted maps.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The multi-glyph entity can push objects marked as small in map data
- [ ] #2 The single-glyph form cannot move those objects
- [ ] #3 Push parameters come from a resource
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Map: legend 'o' (OBJECT), MapData.objects, 5 objects in m1 (rooms only). 2. PushConfig resource; PushableObjects (cells, StaticBody per object, grown-only Sokoban push, reset on run_started, SignalBus.object_moved). 3. ObjectGlyphView: one MultiMesh, glyph-surface shader (free-standing marker, cell from instance origin, no cut-away). 4. Tests (test_pushing incl. reachability), captures 1366/1920, perf, docs.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
IMPLEMENTED (not committed). New: scripts/world/{push_config,pushable_objects}.gd, scripts/rendering/object_glyph_view.gd, resources/config/push_config.tres (via build_resources), tools/test_pushing.gd, tools/capture_pushing.gd. Changed: map_legend/map_data/map_loader (o legend, MapData.objects), world_config (object size/height/collision), world_mesh_builder.build_object, glyph_surface.gdshader (free-standing objects COLOR.b=0.5, cell from instance origin, no cut-away, object_params), glyph_world_view, player.move_intent, signal_bus.object_moved, build_main_scene (main.tscn rebuilt), data/maps/m1_awakening.txt (5 objects: (6,3),(24,9),(35,9),(6,19),(31,20)), docs. Decisions: push axis from input intent + contact (screen-relative input is diagonal in iso, so intent+adjacency picks the axis); collision moves at push start; small objects skip the cut-away; objects do not block light occlusion. EVIDENCE: all tools/test_*.gd PASS headless (test_pushing: reachability, grown push by real input, single blocked, wall/object/void/spikes/corruption/item/spawn/player-cell blocks, signal args, collision follows, reset on run_start); boot 0 ERROR. Sheets scratchpad t019_{push,single,world}_{1366,1920}.png. PERF GTX1060 30fps grown: 1366x768 draws 6.7 GPU 0.48 opening / 0.59 worst; 1920x1061 GPU 0.67 / 0.88 (+1 draw call for objects).
<!-- SECTION:NOTES:END -->
