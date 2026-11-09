---
id: TASK-096
title: Faster discovery, sprint-scaled reveal, bigger sight per form
status: Done
assignee:
  - '@claude'
created_date: '2026-11-09T08:25:00Z'
updated_date: '2026-11-09T09:10:00Z'
labels: []
dependencies: []
priority: medium
type: enhancement
ordinal: 101000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Discovery feels slow: the reveal animation of newly seen cells lags behind movement, so after moving and stopping the area only then becomes visible; at sprint speed the lag is even more visible. The smooth discovery look is liked and stays, it just has to be quicker, scale with sprint, and the seen area should be bigger in the one (single) and many (grown) forms.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Base reveal animation timings (reveal duration, per-cell stagger, memory-to-seen) are half of the previous values
- [x] #2 While sprinting, the reveal timings are divided further by the active sprint speed multiplier
- [x] #3 Reveal radius and player light radius are 2x in the single (one) form and 3x in the grown (many) form; brain form keeps 1x; the factors live in a config resource
- [x] #4 Headless tests cover the timing scale and the per-form area scale
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. RevealConfig: halve reveal_duration, reveal_stagger_per_cell, memory_to_seen_duration; add form_area_scale (single 2, grown 3).
2. MapReveal: time scale = 1/sprint_speed_mult while the player sprints, applied when a cell's animation starts (stored per animation); area scale of the active form (entity_form_changed) multiplies reveal_radius; area_scale() exposed.
3. GlyphWorldView: player light radius x map_reveal.area_scale().
4. Extend tools/test_reveal.gd / new test for scales.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Light occlusion cost grows with radius (~10 ms at 11 cells, ~23 ms at 22 on the dev machine), so the light is not blindly tripled: player_light_radius() = max(map light radius, effective reveal reach). Single 2x reveal (11 cells) matches the old light; grown 3x gives a 16.5 light. Tests: test_reveal (form scale, sprint pace), test_large_objects adapted.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Reveal animation halved (0.45 s, 0.035 s/cell stagger, 0.35 s memory-to-seen) and divided by the sprint speed multiplier while sprinting. RevealConfig.form_area_scale: single 2x, grown 3x reveal radius (brain 1x); the player light reaches at least the revealed area. Verified with test_reveal, test_map_settings, test_large_objects. Risk: larger light radius in the many form costs more occlusion work per cell change on potato hardware.
<!-- SECTION:FINAL_SUMMARY:END -->
