extends SceneTree
## Tests the plugin-style narration lookup (task-048), the SpacetimeDB SQL parsing, the idle ladder and the
## transformation fallback of the narrator (task-049), and the glyph-animation palette parsing (task-054).
## Usage: godot --headless --path . -s tools/test_narration_library.gd --max-fps 30

const CONFIG_PATH := "res://resources/narration/narrator_config.tres"
const ROOT := "user://test_override_library"

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _run() -> void:
	_test_sql_parse()
	_test_lookup()
	_test_narrator_events()
	_test_palette()
	if _failures.is_empty():
		print("PASS test_narration_library")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_narration_library")
		quit(1)


## Real answers captured from the local server (SpacetimeDB 2.14.1).
func _test_sql_parse() -> void:
	var body: Variant = JSON.parse_string('[{"schema":{"elements":[{"name":{"some":"id"},"algebraic_type":{"U32":[]}},{"name":{"some":"version"},"algebraic_type":{"U64":[]}}]},"rows":[[1,7]],"total_duration_micros":110}]')
	var rows: Array = GameDatabase.parse_sql_result(body)
	_check(rows.size() == 1 and int(rows[0]["version"]) == 7 and int(rows[0]["id"]) == 1, "config_version parsed: %s" % [rows])
	body = JSON.parse_string('[{"schema":{"elements":[{"name":{"some":"key"},"algebraic_type":{"String":[]}},{"name":{"some":"first_seen"},"algebraic_type":{}}]},"rows":[["X",[1794144082128801]]]}]')
	rows = GameDatabase.parse_sql_result(body)
	_check(rows.size() == 1 and rows[0]["key"] == "X" and int(rows[0]["first_seen"]) == 1794144082128801, "timestamp unwrapped: %s" % [rows])
	_check(GameDatabase.parse_sql_result(null).is_empty() and GameDatabase.parse_sql_result([]).is_empty(), "bad bodies give no rows")


func _test_lookup() -> void:
	var root_abs: String = ProjectSettings.globalize_path(ROOT)
	_remove_tree(root_abs)
	DirAccess.make_dir_recursive_absolute(root_abs.path_join("narration/event"))
	var cfg := NarrationLibraryConfig.new()
	cfg.override_root = root_abs
	var library := NarrationLibrary.new()
	library.config = cfg
	root.add_child(library)

	var beat := NarrationBeat.new()
	beat.id = "death_spikes_down"
	beat.text = "built-in"
	beat.event = NarrationEvents.DEATH_BY_SPIKES
	# Asset copy (res://narration/event/DEATH_BY_SPIKES_EN_GB.json) is used when there is no override.
	_check(library.line_for(beat) == "Down.", "asset line expected 'Down.', got '%s'" % library.line_for(beat))
	# A player override wins.
	var f := FileAccess.open(root_abs.path_join("narration/event/DEATH_BY_SPIKES_EN_GB.json"), FileAccess.WRITE)
	f.store_string('{"event": "DEATH_BY_SPIKES", "language": "EN_GB", "lines": {"death_spikes_down": "Modded."}}')
	f.close()
	library.clear_cache()
	_check(library.line_for(beat) == "Modded.", "override line expected 'Modded.', got '%s'" % library.line_for(beat))

	# Missing text and audio are recorded once each, as a set, in the missing log.
	beat.event = &"NO_SUCH_EVENT"
	_check(library.line_for(beat) == "built-in", "missing file falls back to the beat text")
	library.note_triggered(&"NO_SUCH_EVENT")
	library.note_triggered(&"NO_SUCH_EVENT")
	var missing: PackedStringArray = library.missing()
	_check(missing.has("NO_SUCH_EVENT_EN_GB_TEXT") and missing.has("NO_SUCH_EVENT_EN_GB_AUDIO"), "missing set: %s" % [missing])
	_check(missing.count("NO_SUCH_EVENT_EN_GB_TEXT") == 1, "missing set holds no duplicates")
	var log_path: String = root_abs.path_join(cfg.missing_log_path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(log_path))
	_check(parsed is Dictionary and (parsed["errors"] as Array).has("NO_SUCH_EVENT_EN_GB_AUDIO"), "missing log written to %s: %s" % [log_path, parsed])
	# A new library reads the stored set back (duplicates across sessions are dropped too).
	var again := NarrationLibrary.new()
	again.config = cfg
	root.add_child(again)
	_check(again.missing().has("NO_SUCH_EVENT_EN_GB_TEXT"), "the missing set survives a restart")

	# DB rows override the path templates.
	library._on_tables_loaded({"narration": [{"event": "CUSTOM", "language": "EN_GB", "text_path": "narration/event/DEATH_BY_SPIKES_EN_GB.json", "sound_path": "x.mp3"}]})
	beat.event = &"CUSTOM"
	_check(library.line_for(beat) == "Modded.", "DB text_path is used")
	library.queue_free()
	again.queue_free()
	_remove_tree(root_abs)


func _test_narrator_events() -> void:
	# Loaded at run time: the narrator script needs the SignalBus autoload, which does not exist when this script compiles.
	var n: Node = load("res://scripts/narrator/narrator.gd").new()
	_check(n != null, "narrator script loads")
	if n == null:
		return
	n.set("config", (load(CONFIG_PATH) as NarratorConfig).duplicate())
	var cfg: NarratorConfig = n.get("config")
	root.add_child(n)
	# Transformations: the specific direction falls back to TRANSFORMED beats.
	var claim: NarrationBeat = n.call("pick_for_event", NarrationEvents.TRANSFORMED_TO_ONE)
	_check(claim == null or NarrationLibrary.event_of(claim) == NarrationEvents.TRANSFORMED, "fallback picks a TRANSFORMED beat")
	n.set("run_count", 4)
	n.set("death_count", 3)
	var one: NarrationBeat = n.call("pick_for_event", NarrationEvents.TRANSFORMED_TO_ONE)
	_check(one != null and one.id == "claim_ai_one", "TRANSFORMED_TO_ONE reaches claim_ai_one")
	_check(n.call("pick_for_event", NarrationEvents.TRANSFORMED_TO_MANY) != null, "TRANSFORMED_TO_MANY reaches the transformation beats")
	# Idle ladder: short, mid, long, each once per run.
	var bus: Node = root.get_node("SignalBus")
	cfg.idle_seconds = 1.0
	cfg.idle_mid_seconds = 2.0
	cfg.idle_long_seconds = 3.0
	bus.emit_signal("run_started", 0)
	n.set("_run_active", true)
	var events_seen: Array[StringName] = []
	for i in 40:
		var before: int = n.get("_idle_step")
		n.call("advance", 0.1)
		var after: int = n.get("_idle_step")
		if after > before:
			events_seen.append([NarrationEvents.IDLE_FOR_SHORT, NarrationEvents.IDLE_FOR_MID, NarrationEvents.IDLE_FOR_LONG][after - 1])
	_check(events_seen == [NarrationEvents.IDLE_FOR_SHORT, NarrationEvents.IDLE_FOR_MID, NarrationEvents.IDLE_FOR_LONG], "idle ladder fired %s" % [events_seen])
	n.queue_free()


func _test_palette() -> void:
	var p: PackedColorArray = GlyphAnimView.parse_palette("#ff0000, nope,#00ff00,#0000ff", 2)
	_check(p.size() == 2 and p[0] == Color(1, 0, 0) and p[1] == Color(0, 1, 0), "palette parse: %s" % [p])


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
