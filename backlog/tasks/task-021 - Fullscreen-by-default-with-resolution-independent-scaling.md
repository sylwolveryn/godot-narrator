---
id: TASK-021
title: Fullscreen by default with resolution-independent scaling
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T17:45:00Z'
updated_date: '2026-10-30T17:58:00Z'
labels:
  - rendering
  - ux
milestone: m-2
dependencies: []
priority: high
type: feature
ordinal: 24000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Playtest: the window is small and every overlay size was tuned only for 960x540. The game should open fullscreen and look the same at any resolution or aspect ratio.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The game starts fullscreen by default (value in project settings or a config resource, not code)
- [ ] #2 ASCII cell size, player glyph, narration text, intro wave and death/erosion effects scale with the window so the composition matches at 1280x720, 1920x1080 and 2560x1440 (verified by captures)
- [ ] #3 Ultrawide and 4:3 windows keep the player centred with no stretched glyphs
- [ ] #4 A key toggles fullscreen/windowed through an InputMap action
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. DisplayConfig resource (reference 1920x1080) + scale = viewport height/ref. 2. Config reference sizes doubled (authored 960x540). 3. AsciiPostProcess/GlyphOverlay/NarrationOverlay/IntroSequence rescale on size_changed (atlas rebuild). 4. FullscreenToggle node + toggle_fullscreen action (F11, Alt+Enter). 5. Project settings via tools/build_project_settings.gd. 6. Movie Maker captures at 5 resolutions + contact sheet.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented. Files: scripts/rendering/display_config.gd (+resources/config/display_config.tres), ascii_post_process.gd, glyph_overlay.gd, narration_overlay.gd, intro_sequence.gd, scripts/ui/fullscreen_toggle.gd, tools/build_project_settings.gd (display/window/size/mode=3, viewport 1920x1080, stretch disabled), build_input_map.gd (toggle_fullscreen), build_main_scene.gd, tools/capture_at_size.sh. Config pixel values doubled to the 1080p reference (cell 20x36, atlas font 32, player font 88, narration 60/outline 16, jitter 14, shard 180, intro cell 20x36); narration width capped by max_text_width. Camera ortho size is vertical (KEEP_HEIGHT) so framing is unchanged; wider aspects show more horizontally. Movie Maker finding: it ignores --resolution/--windowed/window resize and records at the project viewport size (display/window/size/viewport_*; earlier 1152x648 = old default). Working command: tools/capture_at_size.sh WxH <dir> <frames> tools/capture_narrator.gd (writes temporary override.cfg with windowed viewport WxH, deletes after). Evidence: shots in scratchpad shots_021_{1280x720,1920x1080,2560x1440,2560x1080,1024x768}; contact sheets scratchpad/contact_021.png and contact_021_text.png - compositions match, player centred, no stretched glyphs. Boot headless 0 errors; all test_*.gd PASS.
<!-- SECTION:NOTES:END -->
