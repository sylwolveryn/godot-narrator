class_name NarrationLibraryConfig
extends Resource
## Where narration text and sound files are looked up (task-048). Instance: resources/config/narration_library_config.tres.
## Lookup order for a relative path (from the DB `narration` table, else the templates below):
##   1. <override root>/<path>   players drop files here to replace the narration (plugin system)
##   2. <asset_root><path>       the copy bundled with the game
## The override root is `override_root` when set, else the folder of the game executable in an exported build, and
## <project>/`dev_override_dir` when run from the editor / project folder (so the override and the bundled copy are
## different files there too). The missing log lives under the game root (executable folder / project folder).

## Language the narration is read in (an id of the DB table `language_def`).
@export var language: StringName = &"EN_GB"
## Absolute folder that overrides the bundled files; empty = executable folder (export) / dev_override_dir (dev runs).
@export var override_root: String = ""
## Override folder inside the project for dev runs (stands in for the folder next to the executable).
@export var dev_override_dir: String = "override"
## Understanding (0..100) of a language with no DB player_language row.
@export var default_understanding: float = 100.0
@export var asset_root: String = "res://"
## Path templates used when the DB has no row for an event and language. {event} and {language} are replaced.
@export var text_path_template: String = "narration/event/{event}_{language}.json"
@export var sound_path_template: String = "narration/event/{event}_{language}.mp3"
## Sound formats tried in order for a narration sound: the path's extension is swapped for each one, and an empty or
## undecodable file is skipped for the next. WebM (audio only) and M4A are converted to a cached WAV (AudioTranscoder).
@export var sound_formats: PackedStringArray = PackedStringArray(["webm", "mp3", "m4a", "wav"])
## A sound file named <stem><version_marker><anything> (e.g. CORRUPTION_ENTERED_EN_GB_v2.mp3) is another version of the
## <stem> sound; one version is picked at random each time the event plays.
@export var version_marker: String = "_v"
## Where converted M4A files are cached as WAV.
@export var transcode_cache_dir: String = "user://audio_cache"
## Set of missing files, relative to the game root. Entries are <EVENT>_<LANGUAGE>_TEXT / _AUDIO.
@export var missing_log_path: String = "logs/missing-narrations.json"
@export var missing_text_suffix: String = "_TEXT"
@export var missing_audio_suffix: String = "_AUDIO"
## Volume of narration voice files (the synthesised moods keep their own volume).
@export var voice_volume_db: float = -4.0
