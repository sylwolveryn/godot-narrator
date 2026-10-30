---
id: decision-001
title: Narration and menus render on an overlay layer above the ASCII shader
date: '2026-10-30T16:04:00Z'
status: accepted
---
## Context

The ASCII look comes from a full-screen post-process shader (`shaders/ascii_post.gdshader`, CanvasLayer layer 0) that replaces the 3D render with glyphs per cell. Anything drawn beneath that layer, including narration text, menus and the player glyph, is sampled and re-converted, so it would be scrambled or lose legibility. Options considered: (a) overlay layer that bypasses the shader, (b) text designed to survive the shader, (c) hybrid.

## Decision

Overlay bypass. All crisp text lives on a CanvasLayer with layer >= 10 (config value, prototype used 10), above the post-process layer, so the shader never touches it. This covers narration text (including the morphing scramble-to-resolve effect), future in-world menus, and the player identity glyph(s).

Player identity: the glyph is not part of the 3D render. It is drawn on the overlay as a Label/glyph node positioned each frame at `Camera3D.unproject_position(player_world_position)`, centred on that point. The player's 3D body can stay invisible or be a simple mesh for collision/reveal logic only. The identity is therefore independent of the shader cell size, and the multi-glyph entity (M2) is a cluster of overlay glyphs, each positioned from its own 3D offset. Fonts and sizes for overlay glyphs are config values and may be chosen to match the shader cell grid, but alignment to the grid is optional.

Proof: a throwaway prototype (a SceneTree tool that instantiated main.tscn and added a CanvasLayer at layer 10 with a Label and a yellow "@" placed with `unproject_position` of world point (3, 0, -2)) was captured with Movie Maker at 960x540. The line of text and the glyph rendered crisply over the ASCII output, with the glyph at the expected screen position. A text outline is recommended for readability over busy glyph backgrounds. The prototype was deleted.

## Consequences

- Narrator and menu work (TASK-014 and later) builds on an overlay CanvasLayer with layer >= 10; no shader-safe text design is needed.
- Overlay text is not tinted or dithered by the shader. Any ASCII-look cohesion (colour, font matching the cell grid) is done on the overlay side.
- Overlay glyphs do not occlude or react to the 3D scene automatically. Occlusion, if wanted, is the overlay controller's job.
- Per-frame cost: one unproject_position call per identity glyph.
- Open item: how closely overlay glyph size should track `AsciiConfig.cell_size` (visual decision, to be settled with the multi-glyph entity in M2).
