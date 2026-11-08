---
id: TASK-058
title: Merged multi-cell map objects and the gargoyle fountain (G)
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T14:07:00Z'
updated_date: '2026-11-08T14:29:00Z'
labels:
  - world
  - rendering
dependencies: []
priority: high
type: feature
ordinal: 60000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Bigger props should be authored by repeating their character in the map. Adjacent same characters of a mergeable type form one rectangular object scaled to its footprint (GG = twice as wide, GG/GG = twice as big). The gargoyle fountain G is the first such object.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The map legend marks mergeable types; adjacent cells of one type merge into rectangles (non-rectangular groups split into rectangles)
- [x] #2 G renders as one ASCII-art gargoyle fountain scaled to its footprint, blocks movement and line of sight
- [x] #3 Tests cover the merging (1x1, 2x1, 2x2, L-shape)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
LargeObjectDef (scripts/world/large_object_def.gd) + MapLegend.large_objects; LargeObjectMerger row-major rectangles -> MapData.large_objects; MapLoader collision box per object; MapReveal adds blocks_sight types to sight blockers; GlyphLightOcclusion honours MapData.light_blocking_types; LargeObjectView draws one Y-billboard Label3D per colour layer, scaled (w, h) by footprint, reveal-aware with memory tint + fade, animated water at 5 fps from prebuilt texts. Gargoyle def built by tools/build_resources.gd -> resources/config/large_objects/gargoyle_fountain.tres. Label3D needs autowrap_trim_flags = 0 or layers misalign. tools/test_large_objects.gd passes.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
LargeObjectDef + LargeObjectMerger: adjacent cells of a mergeable legend type merge row-major into rectangles (L-shapes split). LargeObjectView draws one ASCII-art piece per object (layered Label3D: stone, eyes, animated stream and basin) scaled to the footprint, reveal-aware; StaticBody3D collision; blocks sight and light. New props need only a def + legend entry. Verified: tools/test_large_objects.gd and captured frames.
<!-- SECTION:FINAL_SUMMARY:END -->
