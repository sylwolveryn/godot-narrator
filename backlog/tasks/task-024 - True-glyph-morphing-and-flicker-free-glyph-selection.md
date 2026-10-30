---
id: TASK-024
title: True glyph morphing and flicker-free glyph selection
status: Done
assignee:
  - '@claude'
created_date: '2026-10-30T17:45:00Z'
updated_date: '2026-10-30T20:39:00Z'
labels:
  - rendering
milestone: m-2
dependencies:
  - TASK-022
documentation:
  - docs/visual_direction.md
priority: high
type: feature
ordinal: 27000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Glyph changes are instant swaps between characters, which read as noise. Glyphs must morph continuously from one shape to another, and the per-cell glyph choice must not flicker when the scene barely changes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A glyph change in the world renders as a continuous shape interpolation over a configurable duration (e.g. signed-distance-field blend), not a swap
- [x] #2 A static scene shows no glyph flicker; small brightness changes do not toggle glyphs back and forth (hysteresis or temporal smoothing)
- [x] #3 A frame sequence in the task notes shows a single glyph morphing smoothly between two characters
- [x] #4 Frame rate stays at 60 FPS at 1920x1080 on the dev machine
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Ramp morph in post shader: mix(sdf[i], sdf[i+1], smoothstep(band)) driven by continuous L (no popping).
2. Reveal / memory->seen morph via mask fade (easeOutQuart), spike pulse and corruption breathing (slow flow warp, two-glyph SDF blend, <=0.5 Hz).
3. glyph_morph canvas shader + GlyphAtlas available for task-025.
4. Measure flicker: capture N static frames, per-cell glyph/colour change counts (python); morph strip for one cell.
5. Measure 1080p frame time.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented with task-023 (same pipeline): ramp morph d=mix(sdf[i],sdf[i+1],smoothstep(band)) in ascii_post, driven by continuous L; reveal fade with easeOutQuart+overshoot and distance stagger; memory->seen lerp 0.35 s; spike pulse 0.4 Hz; corruption breathing (flow-noise warp 3.2 s, noise-picked glyph blend, hue 0.3 Hz, L +-0.12 at 0.25 Hz); reusable glyph_morph canvas shader + GlyphAtlas for task-025.
Flicker measurement (tools/capture_idle.gd, 1920x1080, player idle next to spikes/item/corruption, frames 181-330 = 5 s at 30 fps, python in scratchpad flicker23.py; C:/Users/SYLWOL~1/AppData/Local/Temp/claude/E--git-godot-narrator/9bf6ff4a-2b4c-4f5c-8bbc-2621e15c92c1/scratchpad/flicker_023_after.txt): threshold luma 90: max 6 single-frame glyph changes per cell in 5 s = 1.21/s (limit 2/s), only 6 cells (0.05%) change in any frame pair; ~1% of cells morph at all (limit 15% ambient); largest single-frame pixel flip in a cell 21% (slow corruption morph); max per-cell luminance step 2.6/255 per frame. Everything else in the static scene is bit-identical between frames.
Morph evidence: C:/Users/SYLWOL~1/AppData/Local/Temp/claude/E--git-godot-narrator/9bf6ff4a-2b4c-4f5c-8bbc-2621e15c92c1/scratchpad/strip_024_glyph_morph.png (glyph_morph shader, # -> & in 9 eased steps, shape blends continuously); C:/Users/SYLWOL~1/AppData/Local/Temp/claude/E--git-godot-narrator/9bf6ff4a-2b4c-4f5c-8bbc-2621e15c92c1/scratchpad/strip_024_world_spike_cell.png (one spike cell in the real world render, frames 181-259 every 3rd: A <-> ^ shape and colour breathe smoothly, no swap).
Perf as in task-023 notes (60 FPS held at 1920x1080, GPU 1.2 ms mean).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Glyph changes are continuous SDF blends (ramp morph driven by luminance; reveal fade with overshoot; 0.35 s memory→seen; corruption breathes via slow flow-noise warp, hue 0.3 Hz, luminance 0.25 Hz). Idle 5 s capture: worst cell 1.2 changes/s, ~1% of cells animate, max luminance step 2.6/255. Strips in task notes show # morphing into & and a spike cell breathing A↔^. Shared GlyphAtlas + shaders/glyph_morph.gdshader ready for the overlay (task-025).
<!-- SECTION:FINAL_SUMMARY:END -->
