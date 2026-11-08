# Game Elements (quick sheet)

## Maps
- Files: `data/maps/*.txt`. Map id = file name.
- `m1_awakening.txt`: original maze, start map.
- `m2_arena.txt`: open arena, test map for merged props.
- `m3_dirt.txt`: dirt map (40x30). `#` ring, lots of `D`, tunnels, pockets. Fully revealed, no fog, no darkness.
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
| `T` | teleport ring | none (not in DB) | 3x3 ring of T around a channel char = working pad | walkable floor; centre char (0-9 a-z A-Z) is the channel, even `o`; any other T group = broken (dim cracks, no trip); see Teleports |
| `D` | dirt wall | none | eatable wall | blocks move, sight, light like `#`; walk into it = eaten (crumble, dust, crunch) -> floor; back each run; events WALL_EATEN, WALLS_DEVOURED |
| `G` | gargoyle fountain | none (not in DB) | ASCII gargoyle over animated water basin | blocks movement, sight, light; def: `resources/config/large_objects/gargoyle_fountain.tres` |

- `-` = no DB row listed.

### Merged props
- Adjacent same chars of a "large object" type merge into ONE rectangle, scaled to footprint.
  - `GG` = 2x wide
  - `GG` / `GG` = 2x bigger
- Scan: row-major, extend right, then down. L-shapes split into rectangles.
- New big prop = add a LargeObjectDef + legend entry. Nothing else.

### Teleports
```
TTT
T0T     exact 3x3 ring + channel char in middle = working
TTT     anything else made of T = broken
```
- Channels in order: 0-9, a-z, A-Z (62).
- Step on centre -> go to NEXT HIGHER channel on map (wraps Z -> 0), random pad of it.
  - only own channel / one pad -> nothing happens.
  - leave centre before it fires again.
- Trip = 3 s, no move, no menu:
  - glow-in 0.7 s, colour waves over floor + walls
  - camera eases to target; glyph gone
  - many targets: zoom out full, half pings hop between them, zoom in on chosen
  - arrival wave, area + strength x targets (max 5)
- Arena: 0 x2, 1 x1, 7 x3, one broken ring. 0 -> 1, 1 -> 7 (3), 7 -> 0 (2).
- Code: TeleportPad (parse, route), TeleportSystem (trip), TeleportView (look, waves, camera). Numbers: `resources/config/teleport_config.tres`.
- Signals: teleport_started / teleport_arrived / teleport_finished.

### Map settings (DB `map_settings`)
- One row per map id. No row = old look (fog, darkness, radius 5.5 + line of sight).
- Columns:
  - `reveal_all`: whole map seen from run start (live look)
  - `fog_enabled`: far-side darkening + ambient fade by distance
  - `darkness_enabled`: off = full light, no memory dimming
  - `reveal_radius`, `player_light_radius`, `ambient_level`: < 0 = game default
  - `line_of_sight`: walls / items / dirt hide what is behind
- Applied on map load and DB reload. Code: MapSettingsResolver (picks row), MapSettings (resolve over configs).
- Seed: `m3_dirt` = reveal_all, no fog, no darkness.

### Dirt `D`
- One entry: `SignalBus.dirt_destroy_requested(cell, cause)` -> DirtWalls.destroy. Eating = cause `eaten`. Later: cannon.
- Chunks 16x16 (DirtConfig.chunk_size): one collision body + one mesh per chunk; destroy rebuilds 1-2 chunks only.
- Player digs on through dirt, keeps 75% speed per cell (PlayerConfig.dig_speed_keep). No HIT_WALL for dirt.
- Save: `walls_eaten`, `next_devour_at`. Every random 100-200 eaten -> WALLS_DEVOURED (narrator, 1 of 5 lines at random).
- WALL_EATEN world line "Crumble, dust, destroyed" once ever.
- Crunch: `<override>/sfx/dirt_crunch.mp3` > `<game>/sfx/...` > `res://sfx/...` > synthesized noise. Random pitch, rate-limited.
- Numbers: `resources/config/dirt_config.tres`.

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
  - Items: switch form (one <-> many), "remember" (origin ledger), "language" (pick language).
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
  - WALL_EATEN, WALLS_DEVOURED (dirt)
- NarratorConfig.random_pick_events: equal-rank beats picked at random (WALLS_DEVOURED).
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

## Language (understanding)
- Core progress meter. Per save. New game = English (EN_GB) 0%, selected.
- Gains go to SELECTED language, max 100%:
  - +1% per 20 tiles walked
  - +1% per death (run end)
  - +3% first time ever a new cell type seen (floor, wall, item, spikes, corrupt, object, gargoyle...). Void never.
- Unlock: open menu "language" while selected >= 60% -> next language unlocks at 1% + small glyph storm. One per opening.
  - Order: HU_HU, ALIEN, MATRIX, DREAM, DE_DE, RU_RU, JP_HAN, JP_KANA.
- Menu "language": list "English 37%" per unlocked language + "back". Confirm = select (narration language), menu closes.
- Code: `LanguageProgress` (only writer) + `resources/config/language_config.tres` (all numbers).
- Signals: language_understanding_changed (0..1), language_selected, language_unlocked.
- DB `player_language` mirrors the save (pushed on load and each whole % change). God "Start new game" -> 0%.
- Look follows the selected language's understanding (task-066):
  - World: 0% = old look (glyph grids of floor / hazards / props interleave). Rising % = more glyph cells drawn "layered": one whole glyph per screen cell, owner order floor < spikes / corruption < items / pushable objects. 100% = clean. Config `glyph_world_config` group "Layered clarity".
  - Gargoyles: dark silhouette behind the art fades in with % (no floor glyphs in the gaps at 100%).
  - Player glyph: < 6% hollow outline, no glow; glow (halo, crystal, sparkle) rises from 6% to today's at 100%; colour blunt at 0%, a bit more vivid at 100%. Grown body: same hollow / colour rule. Config `avatar_fx_config` group "Understanding look" (no DB columns).

## Database (SpacetimeDB, local)
- Module: `database/spacetimedb/src/lib.rs`. DB name `database-narrator`. Server `http://127.0.0.1:3000`.
- Game talks plain HTTP. Offline -> bundled `data/db/seed.json`.
- Tables: `event_def`, `language_def`, `narration`, `player_stats`, `player_death`, `player_language`, `missing_narration`, `glyph_anim`, `movement_profile`, `avatar_fx`, `map_settings`, `config_version`.
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
- Tasks: backlog CLI (latest TASK-070).
