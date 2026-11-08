# god

Small Python/tkinter launcher for the Narrator Godot game. Standard library only (Python 3.10+, tested on 3.14).
Godot ignores this folder (`.gdignore`).

## Run

    python god/god.py

Godot is found via the `GODOT_BIN` environment variable, else `godot` on PATH. The project is the repo root
(the parent of `god/`); the game runs as `<godot> --path <repo>`.

## Buttons

- **Start new game**: closes the running game (if any), deletes `%APPDATA%/Godot/app_userdata/Narrator/progress.tres`
  (no error if missing), then starts the game.
- **Continue game**: disabled while the save does not exist (checked every 3 s). If the game is not running it starts it.
  If it is already running, the first click shows a warning and the second click closes and restarts it.
- **Reveal map**: if the game is running, it reveals the map currently in play right away, without a restart.
  god bumps `[commands] reveal_map` in `dev_flags.cfg` and the game's `DevBridge` autoload runs `MapReveal.reveal_all()`.
  The new cells are saved like any other reveal. If the game is not running, it runs the headless tool
  `tools/dev_reveal_map.gd --map=<chosen map>`, which marks every non-void cell of the map chosen in the Map box as
  revealed through the game's own `SaveService`. Disabled only when there is neither a save nor a running game.

- **FPS: on / FPS: off**: toggles the performance overlay (FPS, frametime, CPU time, GPU time with graphs, from the
  vendored [Debug Menu](https://godotengine.org/asset-library/asset/1902) addon in `addons/debug_menu`). god writes
  `dev_flags.cfg` (`[overlay] perf=true|false`) next to the save; the game's `DevBridge` autoload re-reads it every
  0.5 s, so a running game switches at once and later starts keep the setting. Once shown, F3 in the game also cycles it.

- **Map** (task-060): lists `data/maps/*.txt`. Start new game / Continue game start the game on the chosen map as
  `<godot> --path <repo> --max-fps 30 -- --map=<name>` (the game's `MapLoader` reads the user argument and falls back to
  the scene's map). The choice is remembered in `god/settings.json` (gitignored). Map memory in the save is kept per
  map id, so switching maps never touches another map's progress. Note: Start new game deletes the whole save (all maps).

The game is detected even when it was not started by god (any `godot*` process for this repo that is not an
editor `-e`/`--editor` instance or a headless tool run). Closing asks politely, then kills after 5 s.

## Progress section

Shows the fields of `progress.tres` (everything except `revealed_cells`), refreshed by the same 3 s poll when the file
appears, disappears or changes. The file is only ever read. Missing save shows an empty state; a malformed file shows an error.

## Database section

Controls for the local SpacetimeDB server (`http://127.0.0.1:3000`, database `database-narrator`, see
`database/README.md`). The `spacetime` CLI is found via `SPACETIME_BIN`, else on PATH. Everything else goes through
the HTTP API (token from `/v1/identity`, cached and refreshed on a 401).

- **Status**: a green (running) / red (stopped) dot plus `DB: running` / `DB: stopped`, from `GET /v1/ping` on the
  same 3 s poll (grey until the first answer).
- **Start DB**: runs `spacetime start` detached (output in `%TEMP%/narrator_spacetimedb.log`); does nothing if the
  server already answers.
- **Stop DB**: kills the process tree god started. If the server was started elsewhere, lists the `spacetime*`
  processes and asks for confirmation before killing them (`taskkill /T /F`).
- **Publish module**: `spacetime publish database-narrator --server local --yes` in `database/`; output goes to the Log tab.
- **Reload game data**: calls `bump_config_version` so a running game reloads its tables.
- **Clear missing**: calls `clear_missing`.
- **Seed versions (task-020.06)**: the `Seed:` box lists the seed files that exist: `current` = `data/db/seed.json`
  (bundled with the game, loaded when the DB is offline), `previous` = `seed.prev.json`, `old` = `seed.old.json`.
  - **Save DB to seed** writes the DB lookup tables into `seed.json` after rotating the files (old <- previous <-
    current). It is disabled while the DB equals the current seed. Rows keep the order of the old file, so a change
    gives a small diff.
  - **Reseed DB** (asks first) replaces the DB lookup tables with the chosen version through owner SQL, then bumps
    `config_version` so a running game reloads. If a step fails, the touched tables are restored from a backup taken
    first.
  - Gameplay counters are not tuning. `narration.triggered`, `player_language.understanding` and
    `config_version.version` are written to seeds as 0, ignored when comparing, and kept by a reseed.
    `player_language` and `config_version` are never reseeded.
  - The label next to the buttons shows which version the DB equals, or "DB has unsaved changes".

- **Table + Read table / Read all**: `SELECT * FROM <table>` shown in a grid, one tab per table (floats rounded to
  3 decimals, timestamps in local time).
- **Editing (task-061)**: double-click a cell, type, press Enter (or click elsewhere) and it is saved at once; Escape
  cancels. The row key column and timestamps are read only; a value that does not fit the column type is refused in
  the Log tab. Each save runs an SQL `UPDATE` with the database owner's token (the identity the `spacetime` CLI is
  logged in with, read via `spacetime login show --token`; anonymous callers may not run DML) and then calls
  `bump_config_version`, so a running game picks the change up within a few seconds.
- **Ctrl+Z / Ctrl+Y** (also Ctrl+Shift+Z): undo / redo the last saved cell edits (up to 200), written back to the DB
  the same way. They are ignored while a text field has the focus, so its own typing undo is not hijacked.

## Tests

    python -m unittest discover -s god/tests

Headless Godot test for the reveal tool: `godot --headless --path . -s tools/test_dev_reveal_map.gd`
