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
- **Reveal map**: runs the headless tool `tools/dev_reveal_map.gd`, which marks every non-void cell of the M1 map
  revealed through the game's own `SaveService`. Disabled without a save. If the game is running, restart it to see the change.

The game is detected even when it was not started by god (any `godot*` process for this repo that is not an
editor `-e`/`--editor` instance or a headless tool run). Closing asks politely, then kills after 5 s.

## Progress section

Shows the fields of `progress.tres` (everything except `revealed_cells`), refreshed by the same 3 s poll when the file
appears, disappears or changes. The file is only ever read. Missing save shows an empty state; a malformed file shows an error.

## Database section

Controls for the local SpacetimeDB server (`http://127.0.0.1:3000`, database `database-narrator`, see
`database/README.md`). The `spacetime` CLI is found via `SPACETIME_BIN`, else on PATH. Everything else goes through
the HTTP API (token from `/v1/identity`, cached and refreshed on a 401).

- **Status**: `DB: running` / `DB: stopped`, from `GET /v1/ping` on the same 3 s poll.
- **Start DB**: runs `spacetime start` detached (output in `%TEMP%/narrator_spacetimedb.log`); does nothing if the
  server already answers.
- **Stop DB**: kills the process tree god started. If the server was started elsewhere, lists the `spacetime*`
  processes and asks for confirmation before killing them (`taskkill /T /F`).
- **Publish module**: `spacetime publish database-narrator --server local --yes` in `database/`; output goes to the Log tab.
- **Reload game data**: calls `bump_config_version` so a running game reloads its tables.
- **Clear missing**: calls `clear_missing`.
- **Table + Read table / Read all**: `SELECT * FROM <table>` shown in a grid, one tab per table (floats rounded to
  3 decimals, timestamps in local time).

## Tests

    python -m unittest discover -s god/tests

Headless Godot test for the reveal tool: `godot --headless --path . -s tools/test_dev_reveal_map.gd`
