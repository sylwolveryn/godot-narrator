extends SceneTree
## Builds the narration resources from data/narration/m1_beats.json plus data/narration/origin_beats.json
## (appended after it; the lint options come from m1_beats.json):
##   resources/narration/<id>.tres        one NarrationBeat per beat
##   resources/narration/narrator_config.tres   NarratorConfig (beats in table order + sound moods)
## Idempotent. Run after tools/build_origin.gd and before tools/build_main_scene.gd.
## Lints the beats first (NarrationLint) and builds nothing when the lint has errors (exit code 1).
## Usage: godot --headless --path . -s tools/build_narration.gd

const DATA_PATH := "res://data/narration/m1_beats.json"
const EXTRA_DATA_PATHS: PackedStringArray = ["res://data/narration/origin_beats.json"]
const DIR := "res://resources/narration/"
const CONFIG_FILE := "narrator_config.tres"
const ORIGIN_CONFIG_PATH := "res://resources/config/origin_config.tres"


func _init() -> void:
	process_frame.connect(_build, CONNECT_ONE_SHOT)


func _build() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary or not (parsed as Dictionary).get("beats") is Array:
		push_error("Bad beat table at %s" % DATA_PATH)
		quit(1)
		return
	var origin: OriginConfig = load(ORIGIN_CONFIG_PATH) as OriginConfig
	if origin == null:
		push_error("Missing %s: run tools/build_origin.gd first" % ORIGIN_CONFIG_PATH)
		quit(1)
		return
	var rows: Array[NarrationBeat] = []
	for row: Dictionary in (parsed as Dictionary)["beats"]:
		rows.append(_beat_from(row))
	for path in EXTRA_DATA_PATHS:
		var extra: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not extra is Dictionary or not (extra as Dictionary).get("beats") is Array:
			push_error("Bad beat table at %s" % path)
			quit(1)
			return
		for row: Dictionary in (extra as Dictionary)["beats"]:
			rows.append(_beat_from(row))
	var lint_options: Dictionary = (parsed as Dictionary).get("lint", {})
	var report: Dictionary = NarrationLint.lint(rows, origin.nature_ids(), origin.deed_ids(), bool(lint_options.get("strict_contradiction", false)))
	for warning: String in report["warnings"]:
		print("WARNING [narration lint] ", warning)
	if not (report["errors"] as PackedStringArray).is_empty():
		for error: String in report["errors"]:
			push_error("[narration lint] " + error)
		printerr("Narration lint FAILED with %d error(s); nothing was built." % (report["errors"] as PackedStringArray).size())
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(DIR)
	var ok := true
	var beats: Array[NarrationBeat] = []
	var order: int = 0
	for beat in rows:
		beat.order = order
		order += 1
		var path: String = DIR + beat.id + ".tres"
		ok = _save(beat, path) and ok
		beats.append(load(path) as NarrationBeat)

	_remove_stale_beats(beats)
	var config := NarratorConfig.new()
	config.beats = beats
	config.moods = _moods()
	ok = _save(config, DIR + CONFIG_FILE) and ok
	quit(0 if ok else 1)


func _beat_from(row: Dictionary) -> NarrationBeat:
	var beat := NarrationBeat.new()
	beat.id = row["id"]
	beat.text = row["text"]
	beat.trigger = NarrationBeat.Trigger[str(row["trigger"])]
	beat.event = StringName(row.get("event", ""))
	beat.event_param = StringName(row.get("event_param", ""))
	beat.delay = float(row.get("delay", 0.0))
	beat.min_run = int(row["min_run"])
	beat.max_run = int(row["max_run"])
	beat.min_deaths = int(row["min_deaths"])
	beat.once = bool(row["once"])
	beat.mood = StringName(row["mood"])
	beat.supports = PackedStringArray(row.get("supports", []))
	beat.contradicts = PackedStringArray(row.get("contradicts", []))
	beat.role = NarrationBeat.Role[str(row.get("role", "STORY"))]
	beat.layer = NarrationBeat.Layer[str(row.get("layer", "NARRATOR"))]
	return beat


## Deletes beat files from earlier builds so removed beats do not linger.
func _remove_stale_beats(kept: Array[NarrationBeat]) -> void:
	var names: PackedStringArray = PackedStringArray([CONFIG_FILE])
	for beat in kept:
		names.append(beat.id + ".tres")
	for file in DirAccess.get_files_at(DIR):
		if file.ends_with(".tres") and not names.has(file):
			DirAccess.remove_absolute(DIR + file)


## The five ambient moods, quiet and soft. Values are the single source for the sound design.
func _moods() -> Array[NarrationMood]:
	var hum := _mood(&"hum", 2.6, 110.0, 110.0)
	hum.overtone_ratio = 1.5
	hum.overtone_level = 0.35
	hum.attack = 0.8
	hum.release = 1.2
	hum.volume_db = 0.0

	var chime := _mood(&"chime", 1.4, 660.0, 990.0)
	chime.overtone_ratio = 2.0
	chime.overtone_level = 0.3
	chime.attack = 0.02
	chime.release = 1.2
	chime.volume_db = -5.0

	var static_mood := _mood(&"static", 1.2, 140.0, 140.0)
	static_mood.tone_level = 0.0
	static_mood.noise_level = 0.45
	static_mood.crackle = 0.9
	static_mood.attack = 0.05
	static_mood.release = 0.9
	static_mood.volume_db = -6.0

	var drone := _mood(&"low_drone", 3.4, 55.0, 48.0)
	drone.overtone_ratio = 1.505
	drone.overtone_level = 0.6
	drone.attack = 1.0
	drone.release = 1.6
	drone.volume_db = 2.0

	var pulse := _mood(&"pulse", 2.2, 520.0, 520.0)
	pulse.overtone_ratio = 1.5
	pulse.overtone_level = 0.2
	pulse.pulse_count = 4
	pulse.pulse_interval = 0.5
	pulse.pulse_length = 0.22
	pulse.attack = 0.01
	pulse.release = 0.3
	pulse.volume_db = -5.0
	return [hum, chime, static_mood, drone, pulse]


func _mood(id: StringName, duration: float, freq_start: float, freq_end: float) -> NarrationMood:
	var mood := NarrationMood.new()
	mood.id = id
	mood.duration = duration
	mood.freq_start = freq_start
	mood.freq_end = freq_end
	return mood


func _save(res: Resource, path: String) -> bool:
	var uid := ResourceLoader.get_resource_uid(path)
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s: %s" % [path, error_string(err)])
		return false
	if uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(path, uid)
	print("Saved ", path)
	return true
