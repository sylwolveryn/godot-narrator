# Legacy prototype (reference only)

`legacy_main.tscn` is the first Godot experiment, preserved when the main scene was
reset (task-015). The `.gdignore` file keeps Godot from importing or parsing this
folder, so nothing here is loaded at runtime. Do not reference it from game code.

What it did (2D, `CharacterBody2D`):
- Arrow-key movement via `ui_*` actions, camera following the player.
- Press `T` (`transform` action) to morph between two vector glyphs, `W` and `が`,
  with a tween pulse (scale, rotation, fade) and a cooldown.
- `VectorCharacter` interpolated the line points of the two glyph shapes by a
  `form_value` in 0..1 and faded in the dakuten above 0.5. This interpolation idea
  is the part worth revisiting for the glyph morphing pillar.

Known issues at the time of retirement:
- Main script read `$UI/Instructions`, which did not exist (runtime error on boot).
- `transform_character()` switched form twice, so the visible form never changed.
- Speeds, cooldowns and colors were hardcoded constants.
