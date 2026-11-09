---
id: TASK-103
title: Polishing UI
status: To Do
assignee: []
created_date: '2026-11-09T10:25:00Z'
labels:
  - rendering
  - art
  - polish
dependencies: []
priority: low
ordinal: 109000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Leftovers from the gargoyle fountain rebuild (TASK-101, 8 polish rounds with two independent art critiques: match to the concept rose from 3/10 to about 6/10, readability from 4/10 to about 7/10). The fountain now stays on its cells and reads as a glowing basin with a red-eyed winged statue, but these would bring it closer to the concept art (docs/art) and remove remaining rough edges. All must stay potato-friendly (pre-baked data, no post-processing).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Fountains light the floor around them: a cyan static light per fountain in GlyphLightSource.collect / GlyphWorldView (the basin is the concept's light source)
- [ ] #2 Basin and statue follow the map's darkness, fog and memory look like the world glyphs do (today they are self-lit everywhere)
- [ ] #3 Rotating the camera crossfades between neighbouring baked views (or 24-32 views are baked) so the statue no longer pops every 22.5 degrees
- [ ] #4 The statue body has fewer . and : fill cells: a hand-tuned glyph ramp or a per-material ramp (horns, wing bones, face) so the silhouette reads as a gargoyle, not a tower, at default zoom
- [ ] #5 A looping water sound near seen fountains (spatial, low volume)
- [ ] #6 The stream lands visibly in front of the statue from every yaw (today the 3/4 views show it along the statue's edge)
<!-- AC:END -->
