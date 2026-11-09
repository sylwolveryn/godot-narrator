---
id: TASK-091
title: 'Brain form: unlocked by a fully discovered map and two teleports'
status: Done
assignee: []
created_date: '2026-11-08T23:54:00Z'
updated_date: '2026-11-09T00:48:00Z'
labels:
  - gameplay
  - menu
  - rendering
dependencies: []
priority: medium
type: feature
ordinal: 96000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
After a whole map is discovered and the player has teleported twice, the menu offers 'become the brain'. The brain form is a 2x2 block of animated Japanese characters with a constant glow aura of 3 to 9 tiles. Its interact button changes the language.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Menu item appears once one map is fully revealed and two teleports were made (saved)
- [x] #2 Brain form: 2x2 animated Japanese glyphs and a glowing aura pulsing between 3 and 9 tiles
- [x] #3 Interact in the brain form selects the next unlocked language
- [x] #4 Switching back to the other forms works
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
EntityForm.BRAIN. Unlock: MapReveal emits SignalBus.map_fully_revealed when every drawn cell is remembered (dev Reveal map counts); SaveService counts teleport_arrived (teleport_count) and complete_maps; EntityProgression._check_brain (EntityGrowthConfig brain_maps_needed 1, brain_teleports_needed 2) -> unlock_brain + BRAIN_UNLOCKED narration. Brain needs no many-form unlock (current_form, set_form, set_entity_form, run-start restore adjusted). Menu item brain.tres 'become the brain' / 'become one' (ACTION_BRAIN, requires_brain, announce_new -> new-item pulse). BrainView: 4 Label3D billboards, Japanese glyph pool (BrainConfig, grapheme split), cycling, breathing glow outline; PlayerGlyphView hides the heart in brain form. GlyphWorldView + shader aura_geo/aura_color: soft violet glow disc breathing 3..9 tiles. Interactables: interact with nothing in reach in brain form -> SignalBus.language_cycle_requested -> LanguageProgress.cycle (next unlocked, wraps) + BRAIN_LANGUAGE_SHIFT. Narrator maps BRAIN -> TRANSFORMED_TO_BRAIN. Glyph pool lives in BrainConfig for now (TASK-085 moves glyph sets to the DB). Verified: test_brain PASS; windowed run on m6 shows the block and aura at 29-30 FPS. Found and fixed on the way: SaveService._sanitized dropped every progress field added since task-077 on load; test_save now round-trips every stored field.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Brain form: unlocked by a fully discovered map and two teleports; 2x2 cycling Japanese glyphs with a 3-9 tile breathing aura; interact changes the language.
<!-- SECTION:FINAL_SUMMARY:END -->
