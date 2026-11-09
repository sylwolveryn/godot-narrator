# Game Elements (quick sheet)

## Maps
- Files: `data/maps/*.txt`. Map id = file name.
- `m1_awakening.txt`: original maze, start map.
- `m2_arena.txt`: open arena, test map for merged props. Cannons: 1x1 at (18,24), 2x2 at (27,20). Small D patch (12-14, 23-25).
- `m3_dirt.txt`: dirt map (40x30). `#` ring, lots of `D`, tunnels, pockets. Fully revealed, no fog, no darkness.
- `m4_dirt_field.txt`: 200x200. `#` border, all `D`, `@` at (100,100). Default look (fog). Made by `python tools/generate_dirt_field.py`. Only walls + dirt + player.
  - Load ~2.5 s, ~4 ms script per frame digging (dev PC). Check: `tools/test_dirt_field.gd`.
- `m5_shapes.txt`: 200x200 like m4, floor routes carved in the D: golden spiral from `@`, 6 rings, rose (6 petals), Lissajous 3:2, 8 spokes, plaza at centre. Made by `python tools/generate_shapes_map.py` (params in header, seeded, rerun = same file). All routes connect to `@`. 6 L, 6 R, 6 H (>= 55 from spawn), 8 W, 2 O, 2 C next to spawn. Default look (fog, no DB row).
  - Load ~3 s; enemies ~0.2 ms per physics step. Check: `tools/test_shapes_map.gd`.
- Pick map:
  - god window "Map" dropdown
  - run arg: `-- --map=m2_arena`
  - unknown name -> warning, falls back to m1
- Legend source: `scripts/world/map_legend.gd` (built by `tools/build_resources.gd`).

### Map mapping

| char        | type                 | DB table(s)                              | ultra short description                           | important notes                                                                                                                                                                                         |
| ----------- | -------------------- | ---------------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ` ` (space) | void                 | none                                     | outside map                                       | blocks light and sight                                                                                                                                                                                  |
| `.`         | floor                | glyph_anim (`floor`)                     | walkable                                          | shimmering glyphs near player                                                                                                                                                                           |
| `#`         | wall                 | glyph_anim (`wall`)                      | solid                                             | blocks movement, light, sight                                                                                                                                                                           |
| `@`         | spawn                | -                                        | player start                                      | floor; one per map                                                                                                                                                                                      |
| `*`         | item                 | glyph_anim (`item`, anim off by default) | glowing pillar                                    | halo + static light; blocks sight (item itself seen); event ITEM_REVEALED                                                                                                                               |
| `^`         | spikes               | glyph_anim (`spikes`)                    | kill on touch                                     | events HIT_SPIKES, DEATH_BY_SPIKES                                                                                                                                                                      |
| `%`         | corruption           | glyph_anim (`corruption`)                | erodes player inside                              | events CORRUPTION_ENTERED, EROSION_HIGH, DEATH_BY_CORRUPTION; kills at threshold                                                                                                                        |
| `o`         | pushable object      | -                                        | small block                                       | only grown form pushes; one cell per push; cell under it is floor                                                                                                                                       |
| `T`         | teleport ring        | none (not in DB)                         | 3x3 ring of T around a channel char = working pad | walkable floor; centre char (0-9 a-z A-Z) is the channel, even `o`; any other T group = broken (dim cracks, no trip); see Teleports                                                                     |
| `D`         | dirt wall            | none                                     | eatable wall                                      | blocks move, sight, light like `#`; walk into it = eaten (crumble, dust, crunch) -> floor; back each run; events WALL_EATEN, WALLS_DEVOURED                                                             |
| `G`         | gargoyle fountain    | none (not in DB)                         | statue turning with the camera (16 baked views) in a real glowing basin | blocks movement, sight, light; destructible (cannon ball removes whole object); def: `resources/config/large_objects/gargoyle_fountain.tres`                                                            |
| `C`         | cannon               | none (not in DB)                         | ASCII cannon, barrel turns                        | merged like G (1x1, 2x2); blocks movement only; indestructible; interact = fire; see Cannon                                                                                                             |
| `L`         | crawler, left wall   | enemy_def (`crawler`)                    | amber bug `Ж` with legs                           | keeps wall on its left; touch = death; see Enemies                                                                                                                                                      |
| `R`         | crawler, right wall  | enemy_def (`crawler`)                    | same bug                                          | keeps wall on its right                                                                                                                                                                                 |
| `H`         | hunter (seeker)      | enemy_def (`hunter`)                     | red `Ω` with eyes                                 | paths to player inside 16 cells                                                                                                                                                                         |
| `W`         | wanderer (random)    | enemy_def (`wanderer`)                   | green `&`, orbiting dots                          | random runs                                                                                                                                                                                             |
| `O`         | black hole           | none                                     | dark core, swirling glyph rings                   | floor; harmless to player; kills enemies that enter; see Remains                                                                                                                                        |
| `I`         | invulnerability item | none                                     | bobbing, glowing `⚛`                              | floor; walk over = invulnerable (DeathMarksConfig.invulnerable_seconds, 600 s); hidden until its cell is revealed; picked = gone across deaths, back on world reset (game restart); see Invulnerability |

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
- One entry: `SignalBus.dirt_destroy_requested(cell, cause)` -> DirtWalls.destroy. Eating = cause `eaten`, cannon ball = `cannon`.
- Chunks 16x16 (DirtConfig.chunk_size): one mesh per chunk (dirt blocks + floor of eaten cells; world mesh skips dirt cells); collision = one body per chunk row (strip). Destroy rebuilds 1 strip + 1-2 chunk meshes.
- Player digs on through dirt, keeps 75% speed per cell (PlayerConfig.dig_speed_keep). No HIT_WALL for dirt.
- Save: `walls_eaten`, `next_devour_at`. Every random 100-200 eaten -> WALLS_DEVOURED (narrator, 1 of 5 lines at random).
- WALL_EATEN world line "Crumble, dust, destroyed" once ever.
- Crunch: `<override>/sfx/dirt_crunch.mp3` > `<game>/sfx/...` > `res://sfx/...` > synthesized noise. Random pitch, rate-limited.
- Numbers: `resources/config/dirt_config.tres`.

### Cannon `C`
- Stand next to it (8 cells around footprint) -> it turns away from you (smooth, 220 deg/s). You are behind it. Leave -> keeps facing.
- Interact: tap = 1 ball. Hold > 2 s = autofire, 1/s rising to 5/s over 4 s, until release.
- Balls: cone +-15 deg, 11 cells/s, live 100 cells then fade. Bigger cannon = bigger balls. One MultiMesh, glyph + trail.
- Hit:
  - destructible (D, gargoyle, teleport pad, enemies) -> destroyed, ball gone.
  - wall, map edge, cannon, pushable object, player -> bounce. Player never hurt.
  - floor, spikes, corruption, items -> fly over.
- Destroyed things come back at run start (like dirt). Teleport pad hit = cracked, no trips.
- Sound: `sfx/cannon_boom.mp3` override, else synthesized boom. Impact = dirt crunch.
- Numbers: `resources/config/cannon_config.tres` (CannonConfig). Code: CannonSystem (turn, fire), Cannon, CannonBalls (sim), CannonView, CannonBallView, CannonBoomSfx.
- Signals: cannon_fired, cannon_ball_bounced.

### Destructibles (generic)
- Registry node `Destructibles`: owners register `(kind, is_at(cell), destroy(cell, cause))`. Hitters ask `kind_at` / `destroy_at`.
- Owners: DirtWalls (`dirt`), LargeObjects (`gargoyle`, any def with `destructible`), TeleportSystem (`teleport`), EnemySystem (`enemy`).
- Every destruction: `SignalBus.destructible_destroyed(kind, rect, world_position, cause)`. Restore: `destructible_restored`.

### Enemies (L R H W)
- Spawn cell = floor. Code: EnemySystem (only writer), EnemyView (one MultiMesh, all enemies). Config `resources/config/enemy_config.tres`, per kind override = DB `enemy_def` (key `kind`).
- Move cell to cell (4 dirs), smooth. Speeds: crawler 2.2, hunter 2.6, wanderer 1.8 cells/s (player ~4.8).
  - crawler: wall-follow. Wall beside -> round corners toward it, else straight, else turn away, else back. Never loses it. Open floor -> straight until wall.
  - hunter: BFS to player in 33x33 window, repath 0.6 s, max 2 searches per step. Out of window / no path -> wanders.
  - wanderer: random dir, run 3-9 cells, re-roll at junction (35%), blocked or run done. Back only in dead end.
- Blocked: walls, void, dirt (never dig), props, cannons, pushables, other enemies (hold 2 cells while moving; wait 1.2 s then other way).
- Hazards (spikes, corruption): harmless to enemies.
- Touch player (0.3 + body radius) while playing -> run ends once. Cause `enemy_crawler` / `enemy_hunter` / `enemy_wanderer` -> DEATH_BY_ENEMY ("Bitten" world + narrator lines).
- Cannon ball -> destroyed (Destructibles kind `enemy`). Back at run start.
- Hidden until its cell is seen this run.
- DB `enemy_def` cols: speed, lethal, repath_seconds, search_radius, turn_chance, run_min, run_max, diamonds, black_hole.
- Signals: enemies_reset, enemy_destroyed(kind, cell, pos, cause).

### Remains (diamonds, black holes)
- Code: EnemyRemains (only writer), RemainsView (one MultiMesh), DiamondSfx. Config `resources/config/remains_config.tres`.
- Enemy destroyed (any cause): crawler 3, wanderer 2 diamonds `◆` burst onto free cells near (BFS <= 3). Hunter -> black hole on its cell.
- Diamond: walk over = collect. Save `diamonds` (all maps, ever). No other use yet. Glints. Sound `sfx/diamond_pickup.mp3` override, else synth ting.
- Black hole `O` (map) or from hunter: player walks over it, nothing happens (no pull, no damage). Enemy that steps in = destroyed (cause `black_hole`), leaves its remains (hunter in hole = no new hole, same cell). Hunters do not avoid holes.
- Per run: run start = diamonds gone, holes = map's `O` again.
- Events: BLACK_HOLE_FORMED ("Collapse, fold, nothing"), DIAMOND_FOUND ("Cold, bright, yours"); world lines, once ever.
- Signals: diamonds_spawned, diamond_collected(cell, total), black_hole_formed, remains_reset.

### Invulnerability (`⚛`, shield)
- Sources: map `I`; a death passing another 10 stained tiles throws one (DeathMarks); every run after a death starts with 5 s (`Invulnerability.respawn_seconds`, exported on the node; 0 = off). First run of a launch: none.
- While active: spikes / corruption harmless, touching enemy dies (cause `invulnerable`), rotating light-blue glyph shield around the player. Time adds up, runs only while playing.
- Code: Invulnerability (only writer of the time), DeathMarks (items: map + death drops), DeathMarksView (item + shield look). Numbers: `resources/config/death_marks_config.tres`.

## Controls

```
movement: WASD / arrows / gamepad stick or d-pad
          hold left mouse = walk toward cursor
          camera-relative (up = up on screen)
sprint:   hold Left Shift / gamepad L3 or RB (after 1st death)
interact: Space / left click / gamepad X (only next to an interactable, e.g. cannon)
camera:   Q / E rotate
          right mouse drag rotate
          mouse wheel or PgUp / PgDn zoom
```

- Menu (in-world, unlocks after some deaths): Tab or gamepad Start.
  - Nav: W/S or arrows. Confirm: Enter / Space / gamepad A.
  - Items: switch form (one <-> many), "remember" (origin ledger), "language" (pick language).
- Intro skip: Esc, Space, mouse click, gamepad A / Start.
- Interact (Interactables): only when an interactable is in reach (hint glyph over player). Then Space / click go to it: no walking, no menu. Else old meaning. Menu open -> Space = menu confirm.
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
  - DEATH_BY_ENEMY, BLACK_HOLE_FORMED, DIAMOND_FOUND (enemies)
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
  - Gargoyles: the statue (task-101) always has its dark silhouette; flat-art props without baked views fade it in with % (no floor glyphs in the gaps at 100%).
  - Player glyph: < 6% hollow outline, no glow; glow (halo, crystal, sparkle) rises from 6% to today's at 100%; colour blunt at 0%, a bit more vivid at 100%. Grown body: same hollow / colour rule. Config `avatar_fx_config` group "Understanding look" (no DB columns).
- Narration obfuscation (task-067, TASK-100): narrator + world lines (never own lines), per character, by the selected language's understanding.
  - Each character has a threshold (hashed, 45%..92%); past it the character is always right.
  - Roll-over below the threshold: < 10% stable stand-in from `static_glyphs` -> < 30% spins through `wild_glyphs` (6/s) -> above: characters near the right one, the right one more and more often.
  - Unsolved words pulse in a slow wave. Wide stand-ins (CJK, Hangul, Dream) shrink to the letter width (min 0.6).
- Glyph pools per language: DB `language_def` columns (live edit in god):
  - `static_glyphs`, `wild_glyphs`: any single characters; empty = NarratorConfig `obf_static_glyphs` / `obf_wild_glyphs`.
  - `foreign_chance` 0..1: share of stand-ins from the other-alphabet pool (NarratorConfig `obf_foreign_glyphs`).
  - `font`: res:// font for the language's own stand-ins (empty = narration font).
  - Seed: EN_GB Latin extras, HU_HU / DE_DE accented letters, RU_RU Cyrillic, JP_HAN kanji, JP_KANA hiragana + katakana (foreign 5-8%); ALIEN technical symbols (10%); MATRIX half-width kana, kanji, Hangul, Arabic, digits, symbols, emoji (0%); DREAM loops, coils and dots (3%).
  - DREAM font: Noto Sans Vai (SIL OFL, `assets/fonts/dream/`), picked to match `docs/art/languages/dreamConcetionArt.png`.
  - Code: `LanguageGlyphs` (pools), `NarrationLibrary.language_row`, `Narrator.current_glyphs`, `NarrationOverlay`. Preview: `tools/capture_language_glyphs.gd`.

## Database (SpacetimeDB, local)
- Module: `database/spacetimedb/src/lib.rs`. DB name `database-narrator`. Server `http://127.0.0.1:3000`.
- Game talks plain HTTP. Offline -> bundled `data/db/seed.json`.
- Tables: `event_def`, `language_def`, `narration`, `player_stats`, `player_death`, `player_language`, `missing_narration`, `glyph_anim`, `movement_profile`, `avatar_fx`, `map_settings`, `enemy_def`, `config_version`.
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
- Tasks: backlog CLI (latest TASK-100).
- Legend chars used: space . # @ * ^ % o G T D C L R H W O I (+ teleport channels inside T rings).
