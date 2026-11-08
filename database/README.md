# Narrator setup

Local SpacetimeDB database `database-narrator` holding the game's editable lookup tables (narration events,
languages, file paths, glyph animation tuning) and the player's track record. The Godot game talks to it over
plain HTTP; the `god/` launcher has buttons for everything below (Database section).

## Run it

    spacetime start                                               # local server on http://127.0.0.1:3000
    cd database
    spacetime publish database-narrator --server local --yes      # build + upload the module in spacetimedb/
    spacetime sql database-narrator --server local "SELECT * FROM glyph_anim"

`spacetime.json` targets the `local` server. On a schema conflict republish with `--delete-data=always`
(wipes player data too). The module is `spacetimedb/src/lib.rs`; `src/` is the template Rust client
(not used by the game), regenerate its bindings with
`spacetime generate --lang rust --out-dir src/module_bindings --module-path spacetimedb`.

## Tables (all public; ids are UPPERCASE strings)

| Table | Key | Columns |
|---|---|---|
| `event_def` | `id` | `description` |
| `language_def` | `id` | `name` |
| `narration` | `id` (auto_inc) | `event` (indexed), `language`, `triggered`, `text_path`, `sound_path` - one row per event x language |
| `player_stats` | `id` (always 1) | `played_seconds`, `steps`, `transformations`, `deaths` |
| `player_death` | `cause` | `count` |
| `player_language` | `language` | `understanding` (percent 0..100) |
| `missing_narration` | `key` | `first_seen` (Timestamp) |
| `glyph_anim` | `surface` (wall, floor, spikes, corruption, item) | `enabled`, `chars`, `palette` ("#rrggbb,..."), `near_intensity`, `far_intensity`, `radius` (cells), `char_speed` (changes/s), `color_speed` (palette cycles/s) |
| `config_version` | `id` (always 1) | `version` |

Default narration paths: `narration/event/{EVENT}_{LANG}.json` and `.mp3`.

## Reducers

| Reducer | Args | Effect |
|---|---|---|
| `init` | - | seeds defaults on first publish |
| `seed_defaults` | - | inserts missing seed rows only (re-run after adding events/languages) |
| `reset_defaults` | - | wipes event_def, language_def, narration, glyph_anim and re-seeds (player tables untouched) |
| `narration_triggered` | event, language | `triggered += 1` (creates the row if missing) |
| `add_play_stats` | seconds f64, steps u64, transformations u64 | adds to player_stats |
| `record_death` | cause | deaths += 1, player_death[cause] += 1 |
| `set_language_understanding` | language, understanding f32 | sets value clamped to 0..100 |
| `report_missing` | key | inserts once, duplicates ignored |
| `clear_missing` | - | empties missing_narration |
| `bump_config_version` | - | version += 1 so running games reload their tables |
| `upsert_glyph_anim` | surface, enabled, chars, palette, near, far, radius, char_speed, color_speed | insert or replace |

CLI example: `spacetime call database-narrator --server local record_death '"SPIKES"'`

## HTTP API used by the game

- `POST /v1/identity` -> `{"identity": "...", "token": "..."}`
- `POST /v1/database/database-narrator/sql`, header `Authorization: Bearer <token>`, body = SQL text ->
  `[{"schema": {"elements": [{"name": {"some": "col"}, "algebraic_type": {"F32": []}}, ...]}, "rows": [[...], ...]}]`.
  Timestamps are `[micros_since_unix_epoch]`.
- `POST /v1/database/database-narrator/call/<reducer>`, JSON array body of the args -> 200 with an empty body,
  400 text on bad arguments.

---

Get a SpacetimeDB Rust app running in under 5 minutes.

## Prerequisites

- [Rust](https://www.rust-lang.org/tools/install) installed
- [SpacetimeDB CLI](https://spacetimedb.com/install) installed

Install the [SpacetimeDB CLI](https://spacetimedb.com/install) before continuing.

---

## Create your project

Run the `spacetime dev` command to create a new project with a Rust SpacetimeDB module.

This will start the local SpacetimeDB server, compile and publish your module, and generate Rust client bindings.

```bash
spacetime dev --template basic-rs
```



## Explore the project structure

Your project contains both server and client code.

Edit `spacetimedb/src/lib.rs` to add tables and reducers. Use the generated bindings in `src/module_bindings/` to build your client.

```
my-spacetime-app/
├── spacetimedb/             # Your SpacetimeDB module
│   ├── Cargo.toml
│   └── src/
│       └── lib.rs           # Server-side logic
├── Cargo.toml
├── src/
│   ├── main.rs              # Client application
│   └── module_bindings/     # Auto-generated types
└── README.md
```



## Understand tables and reducers

Open `spacetimedb/src/lib.rs` to see the module code. The template includes a `Person` table and two reducers: `add` to insert a person, and `say_hello` to greet everyone.

Tables store your data. Reducers are functions that modify data — they're the only way to write to the database.

```rust
use spacetimedb::{ReducerContext, Table};

#[spacetimedb::table(accessor = person, public)]
pub struct Person {
    name: String,
}

#[spacetimedb::reducer]
pub fn add(ctx: &ReducerContext, name: String) {
    ctx.db.person().insert(Person { name });
}

#[spacetimedb::reducer]
pub fn say_hello(ctx: &ReducerContext) {
    for person in ctx.db.person().iter() {
        log::info!("Hello, {}!", person.name);
    }
    log::info!("Hello, World!");
}
```



## Test with the CLI

Open a new terminal and navigate to your project directory. Then use the SpacetimeDB CLI to call reducers and query your data directly.

```bash
cd my-spacetime-app

# Call the add reducer to insert a person
spacetime call add Alice

# Query the person table
spacetime sql "SELECT * FROM person"
 name
---------
 "Alice"

# Call say_hello to greet everyone
spacetime call say_hello

# View the module logs
spacetime logs
2025-01-13T12:00:00.000000Z  INFO: Hello, Alice!
2025-01-13T12:00:00.000000Z  INFO: Hello, World!
```

## Next steps

- See the [Chat App Tutorial](https://spacetimedb.com/docs/tutorials/chat-app) for a complete example
- Read the [Rust SDK Reference](https://spacetimedb.com/docs/clients/rust) for detailed API docs
