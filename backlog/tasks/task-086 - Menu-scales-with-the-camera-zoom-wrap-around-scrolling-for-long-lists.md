---
id: TASK-086
title: Menu scales with the camera zoom; wrap-around scrolling for long lists
status: Done
assignee: []
created_date: '2026-11-08T23:53:00Z'
updated_date: '2026-11-09T00:18:00Z'
labels:
  - menu
  - ui
dependencies: []
priority: high
type: bug
ordinal: 91000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The in-world menu keeps its world size when the camera zooms, so it is too big or too small. It must look the same at every zoom. Lists longer than fit on screen scroll, and moving past the ends wraps around.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The menu keeps the same on-screen size at every camera zoom
- [x] #2 A list with more items than fit shows a window of rows that scrolls with the selection
- [x] #3 Up on the first item goes to the last item, down on the last goes to the first, scrolling the window
- [x] #4 Works for the item list and every sub list (Language, Items, crafting)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
glyph_menu.gdshader: menu_scale uniform scales every offset and quad. MenuGlyphView: camera_rig export (wired in build_main_scene); scale = current_zoom x fit scale, followed live while shown; centre height grows with a tall page (bottom_gap). Long lists: _fit() measures the room between the player and the top of the screen (zoom-independent), shrinks to min_fit_scale (0.8) first, then windows the list (window_for keeps the selection inside; selecting outside rebuilds the window in place); ^ / v hints in the padding. Pointer indices are whole-list indices. Wrap-around already in MenuController (posmod). Verified: test_menu_scroll PASS (window rule, bottom/top window on wrap, scale follows zoom live, up from first = last), test_menu and test_items_menu PASS; screenshots at zoom 0.55 and 1.6 show the same on-screen size with 12 items (4 rows at 80 %, hints).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The menu keeps its on-screen size at every zoom; long lists shrink a little, then scroll with wrap-around.
<!-- SECTION:FINAL_SUMMARY:END -->
