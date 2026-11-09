class_name DbConfig
extends Resource
## Where and how the game talks to the local SpacetimeDB database (task-048). Instance: resources/config/db_config.tres.
## The game only uses the plain HTTP API (no SDK): a token from /v1/identity, SQL reads and reducer calls.

## Off = never contact the server; the bundled seed is used (tests, offline builds).
@export var enabled: bool = true
@export var base_url: String = "http://127.0.0.1:3000"
@export var database: String = "database-narrator"
## Seconds between polls of `config_version` (a bump from the god tool reloads every table); also the retry interval
## while the server is unreachable.
@export var poll_seconds: float = 5.0
## Seconds between flushes of the player track record (played time, steps, transformations).
@export var flush_seconds: float = 15.0
## HTTP timeout per request, seconds.
@export var request_timeout: float = 3.0
## Reducer calls kept while the server is unreachable; older ones are dropped beyond this.
@export var max_pending_calls: int = 200
## Bundled copy of the lookup tables, used until (or instead of) the server answers.
@export var seed_path: String = "res://data/db/seed.json"
## Tables read on start and on every reload.
@export var tables: PackedStringArray = PackedStringArray(["event_def", "language_def", "narration", "glyph_anim", "movement_profile", "avatar_fx", "player_language", "map_settings", "enemy_def", "glyph_ramp", "craft_def", "death_splat", "config_version"])
