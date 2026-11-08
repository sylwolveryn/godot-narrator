class_name NarrationLibraryConfig
extends Resource
## Where narration text and sound files are looked up (task-048). Instance: resources/config/narration_library_config.tres.
## Lookup order for a relative path (from the DB `narration` table, else the templates below):
##   1. <override root>/<path>   players drop files here to replace the narration (plugin system)
##   2. <asset_root><path>       the copy bundled with the game
## The override root is `override_root` when set, else the folder of the game executable in an exported build and the
## project folder when run from the editor.

## Language the narration is read in (an id of the DB table `language_def`).
@export var language: StringName = &"EN_GB"
## Absolute folder that overrides the bundled files; empty = executable folder (export) / project folder (editor).
@export var override_root: String = ""
@export var asset_root: String = "res://"
## Path templates used when the DB has no row for an event and language. {event} and {language} are replaced.
@export var text_path_template: String = "narration/event/{event}_{language}.json"
@export var sound_path_template: String = "narration/event/{event}_{language}.mp3"
## Set of missing files, relative to the override root. Entries are <EVENT>_<LANGUAGE>_TEXT / _AUDIO.
@export var missing_log_path: String = "logs/missing-narrations.json"
@export var missing_text_suffix: String = "_TEXT"
@export var missing_audio_suffix: String = "_AUDIO"
## Volume of narration voice files (the synthesised moods keep their own volume).
@export var voice_volume_db: float = -4.0
