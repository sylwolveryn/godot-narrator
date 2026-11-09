---
id: TASK-099
title: 'New many form: small human figure slowly morphing between shapes'
status: Done
assignee:
  - '@claude'
created_date: '2026-11-09T08:25:00Z'
updated_date: '2026-11-09T09:10:00Z'
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
- [x] #1 The many form is a human figure about 2 tiles wide and 3 tiles tall made of small body glyphs from the identity palette; the identity glyph is the heart
- [x] #2 The body morphs human -> other shape -> human, each transformation taking 30-50 s, through lion head, angelic winged body and hand shapes
- [x] #3 The morph is visual only: collider size and form mechanics are unchanged by the current shape
- [x] #4 Grow, fold, erosion and death burst still work on the new body
- [x] #5 Shapes and timings live in .tres resources built by a tools/ script; a headless test covers the morph and a capture shows the shapes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. EntityMorph (pure data): resolves base + morph shapes into a fixed slot set (hidden duplicates) and runs the hold/morph clock (human -> other -> human, 30-50 s morphs).
2. EntityGlyphView writes from/to shapes into the instance buffer when a morph starts/ends; shader glides with a morph uniform, flips glyphs half way, fades hidden slots. Heart shrinks to heart_size_ratio.
3. tools/build_entity_growth.gd builds human, lion_head, angelic, hand formations (7x11, small glyphs) and the config; old formations removed.
4. BodyOutline handles a body deeper than wide (capsule along screen up).
5. Tests: test_entity_morph, updated many form tests; capture_many_form.gd for visuals.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Capture (tools/capture_many_form.gd) showed the first palette (warm yellow) vanished on the brown floor; switched to pale cyan/white body glyphs, glyph size 0.42 with a dark outline. Shapes read at default zoom but are small; tuning is in tools/build_entity_growth.gd.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Many form is now a 7x11 grid (~2x3 tiles) human of the identity's body glyphs that morphs human -> lion head / angelic / hand -> human (30-50 s morphs, 12-24 s holds, no shape twice in a row). EntityMorph holds slots and the clock; the shader glides via a morph uniform, flips glyphs half way and fades hidden slots; the buffer is rewritten only at phase changes. Heart shrinks to 0.4. Collider stays the human outline; BodyOutline now lays a deeper-than-wide body along the screen's up. Old winged/beetle/sprite removed. Verified: test_entity_morph, test_entity_growth, test_many_form, test_many_form_contacts, capture frames.
<!-- SECTION:FINAL_SUMMARY:END -->
