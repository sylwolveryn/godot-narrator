---
name: game-design
description: Game design details — mechanics, numbers, content. Use when implementing or modifying gameplay logic, tuning values, or adding content.
---

# Game Design

Read `docs/game_design.md` before implementing or changing any gameplay mechanic, number, or content item. Do not hardcode values from memory; use the numbers in that file.

## Eye candy: the reference example is the teleport trip

The owner called the teleport animation "just wonderful". It is the bar for any new effect.
Code: `scripts/rendering/teleport_view.gd` (task-068). Tuning: `scripts/world/teleport_config.gd` / `resources/config/teleport_config.tres`.
Shader side: the colour-wave block of `shaders/glyph_surface.gdshader` (`wave_count`, `wave_geo`, `wave_col`, `wave_style`).

What makes it work, and what to copy:

1. **The world reacts, not a sprite on top.** The effect is colour waves that run through the existing ASCII
   floor and walls. The glyphs inside a ring take the wave's hue, get brighter and denser. No particles, no overlay
   quads. The world itself is the effect.
2. **It steps in glyph cells.** Each ring is evaluated per glyph cell, so it moves in ASCII steps. It stays true to
   the art style and never looks like a smooth "modern" shader.
3. **A story in three beats, timed by data.** Glow-in at the source (pad glows up, ripples spread out). Then travel:
   the camera eases (smootherstep in/out), and with several destinations it zooms out, pings cycle back and forth over
   the candidates, then it zooms in on the chosen one. Then arrival: a bigger burst on the receiving pad. Every timing,
   share and count is a config value.
4. **Bigger choice, bigger payoff.** The arrival wave's area and strength scale with the number of candidates (clamped).
   The spectacle grows with the moment's meaning.
5. **Colour with intent.** Each beat has its own vibrant colour (cyan source, magenta pings, gold arrival). A partial
   rainbow runs along each ring (`wave_rainbow`), not a full one. Waves fade quadratically and widen with sqrt(scale).
6. **Cheap enough for the potato.** At most 8 waves as shader uniforms (the oldest one is replaced). `wave_count = 0`
   costs nothing. The view only processes while a trip, wave or glow is alive. There are no new nodes per frame and
   no allocations in the loop.
7. **It respects game state.** Pads stay hidden until seen and are tinted while only remembered. A strongly glowing
   candidate shows even in the dark, so the pings read.

When building a new effect, follow this checklist: react through the world's own glyphs, step in cells, tell
beat → travel → payoff, scale the payoff with significance, give each beat its own colour, keep the cost at zero
when idle, and put every number in a config resource.
