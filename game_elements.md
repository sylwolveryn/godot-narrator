# Game Elements (quick sheet)

## Maps
- Files: `data/maps/*.txt`. Map id = file name.
- `m1_awakening.txt`: original maze, start map.
- `m2_arena.txt`: open arena, test map for merged props.
- Pick map:
  - god window "Map" dropdown
  - run arg: `-- --map=m2_arena`
  - unknown name -> warning, falls back to m1
- Legend source: `scripts/world/map_legend.gd` (built by `tools/build_resources.gd`).

### Map mapping

| char | type | DB table(s) | ultra short description | important notes |
|---|---|---|---|---|
| ` ` (space) | void | none | outside map | blocks light and sight |
| `.` | floor | glyph_anim (`floor`) | walkable | shimmering glyphs near player |
| `#` | wall | glyph_anim (`wall`) | solid | blocks movement, light, sight |
| `@` | spawn | - | player start | floor; one per map |
| `*` | item | glyph_anim (`item`, anim off by default) | glowing pillar | halo + static light; blocks sight (item itself seen); event ITEM_REVEALED |
| `^` | spikes | glyph_anim (`spikes`) | kill on touch | events HIT_SPIKES, DEATH_BY_SPIKES |
| `%` | corruption | glyph_anim (`corruption`) | erodes player inside | events CORRUPTION_ENTERED, EROSION_HIGH, DEATH_BY_CORRUPTION; kills at threshold |
| `o` | pushable object | - | small block | only grown form pushes; one cell per push; cell under it is floor |
| `G` | gargoyle fountain | none (not in DB) | ASCII gargoyle over animated water basin | blocks movement, sight, light; def: `resources/config/large_objects/gargoyle_fountain.tres` |

- `-` = no DB row listed.

### Merged props
- Adjacent same chars of a "large object" type merge into ONE rectangle, scaled to footprint.
  - `GG` = 2x wide
  - `GG` / `GG` = 2x bigger
- Scan: row-major, extend right, then down. L-shapes split into rectangles.
- New big prop = add a LargeObjectDef + legend entry. Nothing else.

## Controls

```
movement: WASD / arrows / gamepad stick or d-pad
          hold left mouse = walk toward cursor
          camera-relative (up = up on screen)
sprint:   hold Left Shift / gamepad L3 or RB (after 1st death)
camera:   Q / E rotate
          right mouse drag rotate
          mouse wheel or PgUp / PgDn zoom
```

- Menu (in-world, unlocks after some deaths): Tab or gamepad Start.
  - Nav: W/S or arrows. Confirm: Enter / Space / gamepad A.
  - Items: switch form (one <-> many), "remember" (origin ledger).
- Intro skip: Esc, Space, mouse click, gamepad A / Start.
- Fullscreen: F11 or Alt+Enter.
- No wall cut-away: if a wall hides you, rotate / zoom.

## Player
- Identity: one random glyph per save (e.g. ψ).
- Forms:
  - single (one glyph)
  - grown (many-glyph entity, unlocked after deaths)
- Switch events: TRANSFORMED_TO_ONE / TRANSFORMED_TO_MANY.
- Movement (DB `movement_profile`; fallback PlayerConfig):

| form | speed | accel | decel | feel |
|---|---|---|---|---|
| default | 4.5 | 14 | 16 | - |
| single | 4.8 | 22 | 24 | quick |
| grown | 5.3 | 8 | 10 | slow start, faster top |

- Sprint (unlocks at death_count >= PlayerConfig.sprint_unlock_deaths = 1, checked at spawn):
  - speed x1.5, accel x2.0 while held + moving
  - after sprint: decel x0.45 until stopped = slippery glide
  - let go of Shift, keep walking = ease back to normal
  - DB cols `sprint_speed_mult` / `sprint_accel_mult` / `sprint_decel_mult` (all forms same)
  - first move of a run with sprint = SPRINT_UNLOCKED

- Look (DB `avatar_fx`):
  - slow crystal colour glow on glyph
  - short violet ink trail when moving
  - lean into motion; stretch/squash on accel/brake
- Light radius ~11.
- Discovery: 5.5 cells, line of sight. Blockers: walls, items, gargoyles, void.
- Seen cells remembered between runs (dim "memory" look).

## Narration (plugin style)
- Events = DB ids (table `event_def`). E.g.:
  - RUN_STARTED, FIRST_MOVE, IDLE_FOR_SHORT/MID/LONG
  - WALL/ITEM/SPIKES_REVEALED, CORRUPTION_ENTERED, EROSION_HIGH
  - HIT_WALL, HIT_UNKNOWN, HIT_SPIKES
  - DEATH, DEATH_BY_SPIKES, DEATH_BY_CORRUPTION
  - TRANSFORMED(_TO_ONE/_TO_MANY), ORIGIN_STRUCK, ORIGIN_RECANTED, TIME, SPRINT_UNLOCKED
- Layers (beat `layer` in `data/narration/*.json`), one event plays them in this order:

| layer | look | notes |
|---|---|---|
| WORLD | green + purple, split ghost, glitchy | e.g. "Slow" |
| OWN | player glyph colour, broken words switch | broken share = 100% - `player_language` understanding |
| NARRATOR | blue glow (old look), default | only layer that plays the voice mp3 |

- Languages (`language_def`): EN_GB, HU_HU, ALIEN, MATRIX, DREAM, DE_DE, RU_RU, JP_HAN, JP_KANA.
  - Only EN_GB texts exist so far.
- Files:
  - `narration/event/<EVENT>_<LANG>.json` (`{"lines": {beat_id: text}}`)
  - `.mp3` voice: only empty test pair for RUN_STARTED (see below)
- Lookup: override folder first, then bundled `narration/`.
  - export: override = folder next to exe
  - dev: override = `override/` in project (`override/narration/event/RUN_STARTED_EN_GB.mp3` = read 1st, `narration/event/RUN_STARTED_EN_GB.mp3` = read 2nd)
- Missing file -> `logs/missing-narrations.json` (`{"errors": [...]}`, no duplicates) + DB `missing_narration`.
- Beat logic: `data/narration/*.json` -> `tools/build_narration.gd` -> `.tres`.

## Database (SpacetimeDB, local)
- Module: `database/spacetimedb/src/lib.rs`. DB name `database-narrator`. Server `http://127.0.0.1:3000`.
- Game talks plain HTTP. Offline -> bundled `data/db/seed.json`.
- Tables: `event_def`, `language_def`, `narration`, `player_stats`, `player_death`, `player_language`, `missing_narration`, `glyph_anim`, `movement_profile`, `avatar_fx`, `config_version`.
- Live reload: game polls `config_version` every 5 s. Bump it (god "Reload game data", or auto after god cell edit) -> game re-reads tables.

## God window
Run: `python god/god.py`

- Game: Start new game (wipes save), Continue, Reveal map (m1 only), Map dropdown.
- DB: green/red running light; Start / Stop / Publish module / Reload game data / Clear missing; read tables in grids.
- Edit:
  - double-click cell, Enter saves at once (game reloads), Esc cancels
  - Ctrl+Z / Ctrl+Y undo/redo
  - key columns + timestamps read-only
  - Movement row: load/apply movement profiles

## Dev notes
- Godot 4.7, Compatibility renderer. Potato target: Intel HD 4000, 30 FPS.
- CLI: always `--headless --max-fps 30`.
- Never hand-edit `.tscn` / `.tres`. Use builders in `tools/` (build_resources, build_narration, build_main_scene).
- Tests:
  - `godot --headless --max-fps 30 --path . -s tools/test_x.gd`
  - god: `python -m unittest discover -s god/tests`
- Tasks: backlog CLI (latest TASK-061).
