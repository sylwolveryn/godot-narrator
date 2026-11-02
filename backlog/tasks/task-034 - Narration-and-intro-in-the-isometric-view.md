---
id: TASK-034
title: Narration and intro in the isometric view
status: Done
assignee:
  - '@claude'
created_date: '2026-10-30T22:45:00Z'
updated_date: '2026-11-02T07:02:00Z'
labels:
  - narrator
  - ux
  - rendering
milestone: m-5
dependencies:
  - TASK-031
priority: medium
type: feature
ordinal: 35000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Narration text and the intro wave were tuned for the old top-down, post-processed screen. They must stay legible and on-mood over the new iso glyph world without hiding the player.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Narration lines are legible over the glyph world at 1366x768 and 1920x1080 and never cover the player
- [x] #2 The intro hands off into the iso glyph world without a visual pop
- [x] #3 tools/test_narrator.gd passes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Overlay per-letter eased morph with mood glow. 2. Intro easing. 3. Test + captures.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Overlay letter morph (no scramble), mood glow tints in NarratorConfig, intro easing; test_narrator extended; all tests PASS headless; boot 0 ERROR; captures at 1366x768 and 1920x1080 reviewed; measure: 30 FPS, 4.7 draw calls.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Narration now assembles calmly on the overlay: letters fly in from scattered spots (cubic ease-out, left-to-right stagger), hold with zero per-frame work, then drift up and fade; mood-tinted soft glow per letter; death beats preempt with a fast dispersal. The random-character scramble and its config fields are gone. Lines sit in the lower third clear of the player, entity and menu. Intro: the wave thins over 70% of the reveal and the veil lifts on a sine ease, so the hand-off into the iso world has no step. Validator PASS; test_narrator extended with overlay checks. Open: a dissolve arriving mid-assembly restarts from the rest layout (small jump, rare).
<!-- SECTION:FINAL_SUMMARY:END -->
