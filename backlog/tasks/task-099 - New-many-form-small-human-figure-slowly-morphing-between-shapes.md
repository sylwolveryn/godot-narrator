---
id: TASK-099
title: 'New many form: small human figure slowly morphing between shapes'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-09T08:25:00Z'
updated_date: '2026-11-09T08:47:00Z'
labels: []
dependencies: []
priority: medium
type: feature
ordinal: 104000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The current many (grown) form silhouettes (winged/beetle/sprite, 9x5 glyphs) are disliked. The new body is a 2x3 tile, human-like figure built from small body glyphs (an ascii texture) that very slowly (30-50 s per transformation) morphs into other base shapes - a lion head, a winged angelic body and a hand - and back to the human. It is purely visual: collision and mechanics stay the human 2x3 body. Shape references (documentation only, never loaded): docs/art/forms/many/humanShape.png (base, with the identity's own body glyphs), angelicShape.png, handShapeFront.png, lionHeadFront.png and lionHeadAscii.png.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The many form is a human figure about 2 tiles wide and 3 tiles tall made of small body glyphs from the identity palette; the identity glyph is the heart
- [ ] #2 The body morphs human -> other shape -> human, each transformation taking 30-50 s, through lion head, angelic winged body and hand shapes
- [ ] #3 The morph is visual only: collider size and form mechanics are unchanged by the current shape
- [ ] #4 Grow, fold, erosion and death burst still work on the new body
- [ ] #5 Shapes and timings live in .tres resources built by a tools/ script; a headless test covers the morph and a capture shows the shapes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. EntityMorph (pure data): resolves base + morph shapes into a fixed slot set (hidden duplicates) and runs the hold/morph clock (human -> other -> human, 30-50 s morphs).
2. EntityGlyphView writes from/to shapes into the instance buffer when a morph starts/ends; shader glides with a morph uniform, flips glyphs half way, fades hidden slots. Heart shrinks to heart_size_ratio.
3. tools/build_entity_growth.gd builds human, lion_head, angelic, hand formations (7x11, small glyphs) and the config; old formations removed.
4. BodyOutline handles a body deeper than wide (capsule along screen up).
5. Tests: test_entity_morph, updated many form tests; capture_many_form.gd for visuals.
<!-- SECTION:PLAN:END -->
