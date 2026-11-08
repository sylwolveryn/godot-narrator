extends SceneTree
## Tests the plugin-style narration lookup (task-048), the SpacetimeDB SQL parsing, the idle ladder and the
## transformation fallback of the narrator (task-049), the glyph-animation palette parsing (task-054) and the per-form
## movement profiles of the player (task-055), the narration layers world -> own -> narrator with their looks
## (task-062) and the dev override / missing-log paths (task-064).
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
	_test_movement_profiles()
	_test_layers()
	_test_overlay_layers()
	_test_paths()
	_test_obfuscation()
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
	var library = load("res://scripts/narrator/narration_library.gd").new()
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
	var again = load("res://scripts/narrator/narration_library.gd").new()
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
	_check(claim == null or (NarrationEvents.TIME if claim.trigger == NarrationBeat.Trigger.TIME else claim.event) == NarrationEvents.TRANSFORMED, "fallback picks a TRANSFORMED beat")
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


## The player takes the movement of its form's DB row, falls back to the "default" row, then to PlayerConfig, and
## follows a reload of the table.
func _test_movement_profiles() -> void:
	var db := GameDatabase.new()
	var db_cfg := DbConfig.new()
	db_cfg.enabled = false
	db_cfg.seed_path = ""
	db.config = db_cfg
	root.add_child(db)
	db.tables = {"movement_profile": [
		{"profile": "default", "max_speed": 4.5, "acceleration": 14.0, "deceleration": 16.0},
		{"profile": "single", "max_speed": 4.8, "acceleration": 22.0, "deceleration": 24.0},
		{"profile": "grown", "max_speed": 5.3, "acceleration": 8.0, "deceleration": 10.0}]}
	var player: Node = load("res://scripts/player/player.gd").new()
	player.set("config", PlayerConfig.new())
	player.set("database", db)
	root.add_child(player)
	_check(is_equal_approx(player.get("max_speed"), 4.5) and is_equal_approx(player.get("acceleration"), 14.0), "no form yet: default row")
	root.get_node("SignalBus").emit_signal("entity_form_changed", EntityForm.SINGLE, false)
	_check(is_equal_approx(player.get("acceleration"), 22.0) and is_equal_approx(player.get("deceleration"), 24.0), "single: quick to start and stop")
	root.get_node("SignalBus").emit_signal("entity_form_changed", EntityForm.GROWN, true)
	_check(is_equal_approx(player.get("max_speed"), 5.3) and player.get("acceleration") < 14.0, "grown: slower to accelerate, faster top speed than default")
	db.tables["movement_profile"][2]["max_speed"] = 6.0
	db.tables_loaded.emit(db.tables)
	_check(is_equal_approx(player.get("max_speed"), 6.0), "a DB reload applies during play")
	db.tables = {}
	db.tables_loaded.emit(db.tables)
	var cfg: PlayerConfig = player.get("config")
	_check(is_equal_approx(player.get("max_speed"), cfg.max_speed) and is_equal_approx(player.get("deceleration"), cfg.friction), "no rows: PlayerConfig values")
	player.queue_free()
	db.queue_free()


## SPRINT_UNLOCKED has one line per layer: they play world, own, narrator, each following the previous one as soon as
## it has dissolved (no silence gap); the voice only comes with the narrator line.
func _test_layers() -> void:
	var n: Node = load("res://scripts/narrator/narrator.gd").new()
	var cfg: NarratorConfig = (load(CONFIG_PATH) as NarratorConfig).duplicate()
	n.set("config", cfg)
	root.add_child(n)
	var order: Array[String] = []
	var layers: Array[int] = []
	var times: Array[float] = []
	var clock: Array[float] = [0.0]
	n.beat_started.connect(func(b: NarrationBeat) -> void:
		order.append(b.id)
		layers.append(b.layer)
		times.append(clock[0]))
	root.get_node("SignalBus").emit_signal("run_started", 1)
	n.set("run_count", 2)
	n.set("death_count", 1)
	# Let the run's own start beat (if any) go, then offer the sprint event.
	for i in 400:
		n.call("advance", 0.05)
		clock[0] += 0.05
	order.clear()
	layers.clear()
	times.clear()
	n.call("trigger_event", NarrationEvents.SPRINT_UNLOCKED)
	for i in 600:
		n.call("advance", 0.05)
		clock[0] += 0.05
	_check(order == ["sprint_world_slow", "sprint_own_moving", "sprint_narrator_did_you"], "layer order world, own, narrator: %s" % [order])
	_check(layers == [NarrationBeat.Layer.WORLD, NarrationBeat.Layer.OWN, NarrationBeat.Layer.NARRATOR], "layers %s" % [layers])
	var line_time: float = cfg.morph_in_seconds + cfg.beat_hold_seconds + cfg.morph_out_seconds
	if times.size() == 3:
		_check(times[1] - times[0] < line_time + cfg.beat_gap_seconds * 0.5, "own follows world without the silence gap (%.2f s)" % (times[1] - times[0]))
		_check(times[2] - times[1] < line_time + cfg.beat_gap_seconds * 0.5, "narrator follows own without the silence gap")
	# Once-lines: the event is spent.
	_check(n.call("pick_for_event", NarrationEvents.SPRINT_UNLOCKED) == null, "sprint lines play once")
	# Before the first death nothing plays.
	var fresh: Node = load("res://scripts/narrator/narrator.gd").new()
	fresh.set("config", cfg)
	root.add_child(fresh)
	fresh.set("run_count", 1)
	fresh.set("death_count", 0)
	_check(fresh.call("pick_for_event", NarrationEvents.SPRINT_UNLOCKED) == null, "no sprint lines before the first death")
	fresh.set("death_count", 1)
	var first: NarrationBeat = fresh.call("pick_for_event", NarrationEvents.SPRINT_UNLOCKED)
	_check(first != null and first.layer == NarrationBeat.Layer.WORLD, "the event opens with its world line")
	var followers: Array = fresh.call("layer_followers", first) if first != null else []
	_check(followers.size() == 2, "two later layers follow, got %d" % followers.size())
	n.queue_free()
	fresh.queue_free()


## World lines sweep green / purple and glitch; own lines use the glyph colour and switch not-understood words;
## narrator lines keep the plain text colour and never change letters.
func _test_overlay_layers() -> void:
	var overlay: CanvasLayer = load("res://scripts/narrator/narration_overlay.gd").new()
	var cfg: NarratorConfig = (load(CONFIG_PATH) as NarratorConfig).duplicate()
	overlay.set("config", cfg)
	var pcfg := PlayerConfig.new()
	pcfg.glyph_color = Color(0.2, 0.9, 0.3)
	overlay.set("player_config", pcfg)
	root.add_child(overlay)
	var beat := NarrationBeat.new()
	beat.text = "I was alive and moving"
	beat.layer = NarrationBeat.Layer.OWN
	overlay.call("show_beat", beat, 0.0, "", 0.0)
	_check(overlay.call("_letter_color", 0) == pcfg.glyph_color, "own lines take the glyph colour")
	var changed: bool = false
	for i in 60:
		overlay.call("advance", 0.05)
		if String(overlay.call("shown_text")) != "Iwasaliveandmoving":
			changed = true
	_check(changed, "with no understanding the own line switches its words")
	overlay.call("show_beat", beat, 0.0, "", 1.0)
	var swapped_words: int = 0
	for i in 40:
		overlay.call("advance", 0.05)
		var shown: String = overlay.call("shown_text")
		var diff: int = 0
		for k in shown.length():
			if shown[k] != "Iwasaliveandmoving"[k]:
				diff += 1
		swapped_words = maxi(swapped_words, diff)
	_check(swapped_words <= 3, "full understanding: only a light glitch (%d letters at most)" % swapped_words)
	beat.layer = NarrationBeat.Layer.WORLD
	overlay.call("show_beat", beat, 0.0, "", 1.0)
	var c0: Color = overlay.call("_letter_color", 0)
	_check(c0.g > 0.25 or c0.b > 0.25, "world colour comes from the green / purple sweep: %s" % c0)
	var glitched: bool = false
	for i in 60:
		overlay.call("advance", 0.05)
		if String(overlay.call("shown_text")) != "Iwasaliveandmoving":
			glitched = true
	_check(glitched, "world lines glitch")
	beat.layer = NarrationBeat.Layer.NARRATOR
	overlay.call("show_beat", beat, 0.0, "", 1.0)
	var steady: bool = true
	for i in 60:
		overlay.call("advance", 0.05)
		if String(overlay.call("shown_text")) != "Iwasaliveandmoving":
			steady = false
	_check(steady and overlay.call("_letter_color", 0) == cfg.text_color, "narrator lines at full understanding never change letters")
	overlay.queue_free()


## Dev runs: the override folder is <project>/override (not the bundled folder itself); the missing log stays under the
## game root; understanding comes from player_language.
func _test_paths() -> void:
	var library = load("res://scripts/narrator/narration_library.gd").new()
	library.config = NarrationLibraryConfig.new()
	root.add_child(library)
	var game: String = library.game_root()
	_check(library.override_root() == game.path_join("override"), "dev override root: %s" % library.override_root())
	_check(library.override_root() != ProjectSettings.globalize_path("res://").trim_suffix("/"), "override differs from the bundled folder")
	_check(library.resolve("narration/event/RUN_STARTED_EN_GB.mp3") == library.override_root().path_join("narration/event/RUN_STARTED_EN_GB.mp3"),
		"the override mp3 is found before the bundled one: %s" % library.resolve("narration/event/RUN_STARTED_EN_GB.mp3"))
	_check(library.call("_missing_path") == game.path_join("logs/missing-narrations.json"), "missing log under the game root")
	_check(is_equal_approx(library.understanding(), 1.0), "no DB: default understanding 100%")
	var db := GameDatabase.new()
	var db_cfg := DbConfig.new()
	db_cfg.enabled = false
	db_cfg.seed_path = ""
	db.config = db_cfg
	root.add_child(db)
	db.tables = {"player_language": [{"language": "EN_GB", "understanding": 40.0}]}
	library.database = db
	_check(is_equal_approx(library.understanding(), 0.4), "understanding from player_language")
	library.queue_free()
	db.queue_free()


## Narrator / world obfuscation by understanding (task-067): stable stand-ins below 10%, wild spin up to 30%, near
## characters converging after, every character past its threshold always right; own lines are never obfuscated.
func _test_obfuscation() -> void:
	var overlay: CanvasLayer = load("res://scripts/narrator/narration_overlay.gd").new()
	var cfg: NarratorConfig = (load(CONFIG_PATH) as NarratorConfig).duplicate()
	overlay.set("config", cfg)
	root.add_child(overlay)
	var text: String = "Did you see the wall"
	var plain: String = text.replace(" ", "")
	var beat := NarrationBeat.new()
	beat.text = text
	beat.layer = NarrationBeat.Layer.NARRATOR

	overlay.call("show_beat", beat, 0.0, "", 0.05)
	var first: String = overlay.call("shown_text")
	var same: bool = true
	for i in 40:
		overlay.call("advance", 0.05)
		if String(overlay.call("shown_text")) != first:
			same = false
	var all_hidden: bool = true
	for k in plain.length():
		if first[k] == plain[k]:
			all_hidden = false
	_check(same, "below 10%: a stable obfuscated line ('%s')" % first)
	_check(all_hidden, "below 10%: no character readable yet ('%s')" % first)
	_check(overlay.call("_is_animated"), "an obfuscated narrator line keeps redrawing (waves)")

	overlay.call("show_beat", beat, 0.0, "", 0.2)
	var seen: Dictionary = {}
	var wild_only: bool = true
	for i in 40:
		overlay.call("advance", 0.05)
		var shown: String = overlay.call("shown_text")
		seen[shown] = true
		for k in shown.length():
			if not cfg.obf_wild_glyphs.contains(shown[k]):
				wild_only = false
	_check(seen.size() > 3, "10-30%: the stand-ins spin (%d variants)" % seen.size())
	_check(wild_only, "10-30%: stand-ins come from the wild set")

	overlay.call("show_beat", beat, 0.0, "", 0.6)
	var right: int = 0
	var total: int = 0
	var near_ok: bool = true
	for i in 60:
		overlay.call("advance", 0.05)
		var shown: String = overlay.call("shown_text")
		for k in shown.length():
			total += 1
			if shown[k] == plain[k]:
				right += 1
			elif plain[k] >= "a" and plain[k] <= "z" and not (shown[k] >= "a" and shown[k] <= "z"):
				near_ok = false
	_check(right * 2 > total, "60%%: mostly readable (%d / %d right)" % [right, total])
	_check(near_ok, "30%+: stand-ins of lower-case letters stay lower-case letters")

	# A character past its threshold is always right, in every word, while others may still spin.
	var d_threshold: float = overlay.call("threshold_of", "d")
	var probe := NarrationBeat.new()
	probe.text = "Did odd dad"
	probe.layer = NarrationBeat.Layer.WORLD
	overlay.call("show_beat", probe, 0.0, "", d_threshold)
	var d_always: bool = true
	for i in 60:
		overlay.call("advance", 0.05)
		var shown: String = overlay.call("shown_text")
		var src: String = "Didodddad"
		for k in src.length():
			if src[k].to_lower() == "d" and shown[k] != src[k] and not cfg.glitch_glyphs.contains(shown[k]):
				d_always = false
	_check(d_always, "an understood character never shows a stand-in (only the world style glitch may touch it)")
	_check(overlay.call("is_understood", "D", d_threshold), "understanding is case-insensitive")

	overlay.call("show_beat", beat, 0.0, "", cfg.obf_found_max)
	_check(String(overlay.call("shown_text")) == plain and not overlay.call("_is_animated"), "at the top threshold every character is found and the line rests")

	beat.layer = NarrationBeat.Layer.OWN
	overlay.call("show_beat", beat, 0.0, "", 0.0)
	_check(not overlay.call("_obfuscates"), "own lines are never obfuscated")
	overlay.queue_free()

