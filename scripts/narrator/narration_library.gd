class_name NarrationLibrary
extends Node
## Resolves the narration text and sound files of an event in the current language (task-048), plugin style:
## the override folder first (players replace files there), then the bundled assets. A file found in neither is
## recorded once in the missing set (logs/missing-narrations.json, {"errors": [...]}) and reported to the DB.
## Every triggered event counts towards its `narration.triggered` in the DB.
##
## A text file is JSON: {"event": "DEATH_BY_SPIKES", "language": "EN_GB", "lines": {"<beat id>": "text", ...},
## "default": "optional text for a beat id the file does not list"}. Sound files are MP3.

@export var config: NarrationLibraryConfig
## Optional: DB rows for the paths, and the writer for trigger counts and missing files.
@export var database: GameDatabase

## "EVENT|LANG" -> [text path, sound path] from the DB `narration` table.
var _paths: Dictionary[String, PackedStringArray] = {}
## Resolved files, cached per absolute path: Dictionary (text) or AudioStream; null = looked up and missing.
var _text_cache: Dictionary[String, Variant] = {}
var _audio_cache: Dictionary[String, Variant] = {}
var _missing: Dictionary[String, bool] = {}


func _ready() -> void:
	if config == null:
		config = NarrationLibraryConfig.new()
	# The language changes at run time (task-065); keep the shared resource untouched.
	config = config.duplicate() as NarrationLibraryConfig
	_load_missing()
	SignalBus.language_selected.connect(set_language)
	if database != null:
		database.tables_loaded.connect(_on_tables_loaded)
		_on_tables_loaded(database.tables)


func language() -> StringName:
	return config.language


## Switches the narration language: from now on events read <EVENT>_<language> files.
func set_language(language: StringName) -> void:
	if language == &"" or language == config.language:
		return
	config.language = language
	clear_cache()


## The game's own folder: next to the executable in an exported build, the project folder in dev runs.
func game_root() -> String:
	if not OS.has_feature("template"):
		return ProjectSettings.globalize_path("res://").trim_suffix("/")
	return OS.get_executable_path().get_base_dir()


## Folder that overrides the bundled files (plugin folder).
func override_root() -> String:
	if config.override_root != "":
		return config.override_root
	if not OS.has_feature("template"):
		return game_root().path_join(config.dev_override_dir)
	return game_root()


## Understanding of the narration language as 0..1, from the DB table player_language (percent).
func understanding() -> float:
	if database != null:
		for row: Variant in database.rows("player_language"):
			if row is Dictionary and str((row as Dictionary).get("language", "")) == str(config.language):
				return clampf(float((row as Dictionary).get("understanding", config.default_understanding)) / 100.0, 0.0, 1.0)
	return clampf(config.default_understanding / 100.0, 0.0, 1.0)


## An event was triggered: resolve its files (logging what is missing) and count it in the DB.
func note_triggered(event: StringName) -> void:
	if event == &"":
		return
	_text_for_event(event)
	audio_for(event)
	if database != null:
		database.call_reducer("narration_triggered", [str(event), str(config.language)])


## The text a beat shows: its line in the event's narration file, else the file's default, else the beat's own text.
func line_for(beat: NarrationBeat) -> String:
	var doc: Dictionary = _text_for_event(event_of(beat))
	var lines: Variant = doc.get("lines", {})
	if lines is Dictionary and (lines as Dictionary).has(beat.id):
		return str((lines as Dictionary)[beat.id])
	if doc.has("default"):
		return str(doc["default"])
	return beat.text


## The voice of an event in the current language, or null.
func audio_for(event: StringName) -> AudioStream:
	var rel: String = _path(event, 1)
	var found: String = resolve(rel)
	if found == "":
		_report_missing(event, config.missing_audio_suffix)
		return null
	if not _audio_cache.has(found):
		_audio_cache[found] = _load_audio(found)
	return _audio_cache[found] as AudioStream


## Absolute (or res://) path of the first existing copy of a relative path, override folder first; "" when none.
func resolve(rel: String) -> String:
	if rel == "":
		return ""
	var override: String = override_root().path_join(rel)
	if FileAccess.file_exists(override):
		return override
	var asset: String = config.asset_root.path_join(rel)
	if FileAccess.file_exists(asset) or ResourceLoader.exists(asset):
		return asset
	return ""


## Like `resolve`, for files that are not narration (e.g. sound effects, task-070): the override folder, then the game
## folder, then the bundled asset. "" when none exists.
func resolve_file(rel: String) -> String:
	if rel == "":
		return ""
	for path in [override_root().path_join(rel), game_root().path_join(rel)]:
		if FileAccess.file_exists(path):
			return path
	var asset: String = config.asset_root.path_join(rel)
	if FileAccess.file_exists(asset) or ResourceLoader.exists(asset):
		return asset
	return ""


## Loads an MP3 found by `resolve` / `resolve_file` (null for an empty or unreadable file).
func load_audio(path: String) -> AudioStream:
	return _load_audio(path)


## The missing-file set, sorted.
func missing() -> PackedStringArray:
	var out := PackedStringArray(_missing.keys())
	out.sort()
	return out


## Drops the cached files so overrides dropped in while the game runs are picked up.
func clear_cache() -> void:
	_text_cache.clear()
	_audio_cache.clear()


static func event_of(beat: NarrationBeat) -> StringName:
	return NarrationEvents.TIME if beat.trigger == NarrationBeat.Trigger.TIME else beat.event


func _path(event: StringName, column: int) -> String:
	var key: String = "%s|%s" % [event, config.language]
	if _paths.has(key):
		return _paths[key][column]
	var template: String = config.text_path_template if column == 0 else config.sound_path_template
	return template.format({"event": str(event), "language": str(config.language)})


func _text_for_event(event: StringName) -> Dictionary:
	var found: String = resolve(_path(event, 0))
	if found == "":
		_report_missing(event, config.missing_text_suffix)
		return {}
	if not _text_cache.has(found):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(found))
		if not parsed is Dictionary:
			push_warning("NarrationLibrary: %s is not a JSON object" % found)
			parsed = {}
		_text_cache[found] = parsed
	return _text_cache[found] as Dictionary


## The raw file wins when it can be read (a swapped file works without a reimport); exported builds only have the
## imported resource. An empty file gives no sound.
func _load_audio(path: String) -> AudioStream:
	if FileAccess.file_exists(path):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if bytes.is_empty():
			return null
		var stream := AudioStreamMP3.new()
		stream.data = bytes
		return stream
	if path.begins_with("res://") and ResourceLoader.exists(path):
		return load(path) as AudioStream
	return null


func _report_missing(event: StringName, suffix: String) -> void:
	var key: String = "%s_%s%s" % [event, config.language, suffix]
	if _missing.has(key):
		return
	_missing[key] = true
	_save_missing()
	if database != null:
		database.call_reducer("report_missing", [key])


func _missing_path() -> String:
	if config.override_root != "":
		return config.override_root.path_join(config.missing_log_path)
	return game_root().path_join(config.missing_log_path)


func _load_missing() -> void:
	var path: String = _missing_path()
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and (parsed as Dictionary).get("errors") is Array:
		for key: Variant in (parsed as Dictionary)["errors"]:
			_missing[str(key)] = true


func _save_missing() -> void:
	var path: String = _missing_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("NarrationLibrary: cannot write %s" % path)
		return
	file.store_string(JSON.stringify({"errors": Array(missing())}, "\t") + "\n")


func _on_tables_loaded(tables: Dictionary) -> void:
	_paths.clear()
	for row: Variant in tables.get("narration", []):
		if not row is Dictionary:
			continue
		var r: Dictionary = row
		_paths["%s|%s" % [r.get("event", ""), r.get("language", "")]] = PackedStringArray([str(r.get("text_path", "")), str(r.get("sound_path", ""))])
	clear_cache()
