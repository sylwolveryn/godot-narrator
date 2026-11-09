---
id: TASK-090
title: 'Many form: whole-body fit check before switching, wider zoom'
status: Done
assignee: []
created_date: '2026-11-08T23:54:00Z'
updated_date: '2026-11-09T00:31:00Z'
labels:
  - gameplay
  - camera
dependencies: []
priority: high
type: feature
ordinal: 95000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Switching to the many form must be refused when the whole grown body does not fit where the player stands (walls, objects). The whole body collides, not only the main glyph. A refusal has narration. The many form allows a further zoom-out. Maps where the many form never fits are not changed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The switch is refused when any cell of the grown footprint is blocked; a narration line explains it
- [x] #2 In the many form every glyph of the body collides with walls and objects
- [x] #3 The many form's max zoom distance is larger (config value)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
EntityGrowthConfig.body_radius_for(identity): half the formation width (widest glyph from the heart x advance + half a glyph), about 4.25 for the 9-wide formations; whole_body switch (default on). EntityProgression.fits(form, at): CylinderShape3D query of that radius at the player (or spawn) against layer 1 bodies; set_form refuses with FORM_BLOCKED; the run-start grow moment waits for a spawn with room. Player.apply_body_radius: own capsule copy takes the radius in the grown form. CameraViewConfig.form_zoom {grown: 1.6}: CameraRig.zoom_limit scales zoom_max and the requested zoom moves with the form; TeleportView uses zoom_limit. Only m6 has room for the grown body (6-cell open square); other maps refuse it, as agreed. Older tests (entity growth, pushing, menu) run with whole_body off. test_many_form PASS on m6 (refusal by a wall + narration, success in the open, collision radius, zoom limit x1.6 and back).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The many form must fit as a whole before switching (narrated refusal), collides with its whole body and zooms out 1.6x further.
<!-- SECTION:FINAL_SUMMARY:END -->
