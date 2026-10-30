extends SceneTree
## Headless test of persistent progress (task-013): round trip, save on run end, load before the
## first run, and fallback for missing / garbage / wrong-type / script-carrying files.
## Only temporary save paths are used; they are removed at the end.
## Usage: godot --headless --path . -s tools/test_save.gd

const Support := preload("res://tools/test_support.gd")
const PATH := "user://test_progress_save.tres"
const MAP_ID := &"m1_awakening"
const MEMORY := 1

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _service(path: String) -> Node:
	var cfg := SaveConfig.new()
	cfg.save_path = path
	var svc: Node = load("res://scripts/core/save_service.gd").new()
	svc.set("config", cfg)
	root.add_child(svc)
	return svc


func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _is_fresh(p: PersistentProgress) -> bool:
	return p.identity_glyph == "" and p.run_count == 0 and p.death_count == 0 and p.revealed_cells.is_empty() and p.heard_beats.is_empty()


func _seed() -> PersistentProgress:
	var p := PersistentProgress.new()
	p.identity_glyph = "Q"
	p.run_count = 3
	p.death_count = 5
	p.heard_beats = PackedStringArray(["wake", "first_death"])
	p.revealed_cells = {MAP_ID: PackedVector2Array([Vector2(1, 1), Vector2(2, 1), Vector2(3, 1)])}
	return p


func _run() -> void:
	Support.remove_file(PATH)

	# --- Missing file: fresh defaults, no crash. ---
	var svc: Node = _service(PATH)
	_check(_is_fresh(svc.get("progress")), "missing file should give fresh progress")
	_check(not FileAccess.file_exists(PATH), "loading must not create the file")

	# --- Round trip, and only persistent values are stored. ---
	svc.set("progress", _seed())
	svc.save_progress()
	_check(FileAccess.file_exists(PATH), "save_progress should write the file")
	_check(not FileAccess.file_exists(PATH.get_basename() + ".tmp.tres"), "atomic temp file should be gone")
	var text: String = FileAccess.get_file_as_string(PATH)
	for banned in ["elapsed", "end_cause", "erosion", "input_scheme", "run_index"]:
		_check(not text.contains(banned), "saved file contains per-run value '%s'" % banned)
	var stored_props: PackedStringArray = []
	for prop in PersistentProgress.new().get_property_list():
		if prop["usage"] & PROPERTY_USAGE_STORAGE and prop["name"] != "script" and not String(prop["name"]).begins_with("resource_"):
			stored_props.append(prop["name"])
	stored_props.sort()
	_check(stored_props == PackedStringArray(["death_count", "heard_beats", "identity_glyph", "revealed_cells", "run_count"]), "unexpected persistent fields: %s" % [stored_props])
	svc.load_progress()
	var p: PersistentProgress = svc.get("progress")
	_check(p.identity_glyph == "Q" and p.run_count == 3 and p.death_count == 5, "scalar fields did not round trip")
	_check(p.heard_beats == PackedStringArray(["wake", "first_death"]), "heard_beats did not round trip")
	_check(p.revealed_cells.get(MAP_ID, PackedVector2Array()) == PackedVector2Array([Vector2(1, 1), Vector2(2, 1), Vector2(3, 1)]), "revealed_cells did not round trip")

	# --- A run ending saves (and counts the death). ---
	root.get_node("SignalBus").emit_signal("run_ended", &"test")
	_check((svc.get("progress") as PersistentProgress).death_count == 6, "death_count should be 6, got %d" % (svc.get("progress") as PersistentProgress).death_count)
	var reread: Node = _service(PATH)
	_check((reread.get("progress") as PersistentProgress).death_count == 6 and (reread.get("progress") as PersistentProgress).identity_glyph == "Q", "run end should have written the file")
	reread.free()

	# --- Garbage bytes. ---
	var bytes := PackedByteArray()
	for i in 256:
		bytes.append((i * 37 + 11) % 256)
	var gf := FileAccess.open(PATH, FileAccess.WRITE)
	gf.store_buffer(bytes)
	gf.close()
	svc.load_progress()
	_check(_is_fresh(svc.get("progress")), "garbage file should give fresh progress")

	# --- Truncated text file. ---
	svc.set("progress", _seed())
	svc.save_progress()
	var good: String = FileAccess.get_file_as_string(PATH)
	_write_text(PATH, good.substr(0, good.length() / 2))
	svc.load_progress()
	_check(_is_fresh(svc.get("progress")) or (svc.get("progress") as PersistentProgress).identity_glyph == "Q", "truncated file must not crash")

	# --- Wrong resource type. ---
	ResourceSaver.save(RunConfig.new(), PATH)
	svc.load_progress()
	_check(_is_fresh(svc.get("progress")), "wrong resource type should give fresh progress")

	# --- A file carrying its own script is never loaded. ---
	_write_text(PATH, "[gd_resource type=\"Resource\" format=3]\n\n[sub_resource type=\"GDScript\" id=\"GDScript_1\"]\nscript/source = \"extends Resource\\nvar pwned = true\"\n\n[resource]\nscript = SubResource(\"GDScript_1\")\n")
	svc.load_progress()
	_check(_is_fresh(svc.get("progress")), "file with an embedded script should be rejected")
	_write_text(PATH, "[gd_resource type=\"Resource\" script_class=\"RunConfig\" format=3]\n\n[ext_resource type=\"Script\" path=\"res://scripts/core/run_config.gd\" id=\"1\"]\n\n[resource]\nscript = ExtResource(\"1\")\n")
	svc.load_progress()
	_check(_is_fresh(svc.get("progress")), "file referencing another script should be rejected")

	# --- Out-of-range / mistyped values are sanitized. ---
	var odd := PersistentProgress.new()
	odd.identity_glyph = "ABCDEFGHIJKLMNOP"
	odd.run_count = -4
	odd.death_count = -1
	odd.revealed_cells = {MAP_ID: "not cells", &"ok_map": PackedVector2Array([Vector2(0, 0)])}
	ResourceSaver.save(odd, PATH)
	svc.load_progress()
	_check((svc.get("progress") as PersistentProgress).identity_glyph.length() <= (svc.get("config") as SaveConfig).max_identity_length, "identity length should be capped")
	_check((svc.get("progress") as PersistentProgress).run_count == 0 and (svc.get("progress") as PersistentProgress).death_count == 0, "negative counts should clamp to 0")
	_check(not (svc.get("progress") as PersistentProgress).revealed_cells.has(MAP_ID) and (svc.get("progress") as PersistentProgress).revealed_cells.has(&"ok_map"), "mistyped revealed_cells entries should be dropped")
	svc.free()

	# --- Loaded before the first run: the first run after launch uses the stored progress. ---
	var seeded := _seed()
	seeded.revealed_cells = {MAP_ID: PackedVector2Array([Vector2(1, 1), Vector2(2, 1)])}
	ResourceSaver.save(seeded, PATH)
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var cfg := SaveConfig.new()
	cfg.save_path = PATH
	main.get_node("SaveService").set("config", cfg)
	var intro := IntroConfig.new()
	intro.black_hold = 0.05
	intro.wave_fade_in = 0.05
	intro.wave_hold = 0.05
	intro.reveal_duration = 0.05
	main.get_node("IntroSequence").set("config", intro)
	var run_cfg: RunConfig = (main.get_node("RunManager").get("config") as RunConfig).duplicate()
	run_cfg.restart_delay = 0.0
	main.get_node("RunManager").set("config", run_cfg)
	root.add_child(main)
	var runs: Node = main.get_node("RunManager")
	var progress: PersistentProgress = main.get_node("SaveService").get("progress")
	_check(progress.identity_glyph == "Q" and progress.death_count == 5, "progress should be loaded before any run")
	await create_timer(0.6).timeout
	_check(runs.get("phase") == 1, "first run should be playing")
	_check(str(main.get_node("Player").get("identity_glyph")) == "Q", "first run should use the stored identity")
	_check(progress.run_count == 4, "run_count should continue from the stored 3, got %d" % progress.run_count)
	var reveal: Node = main.get_node("MapReveal")
	_check(reveal.call("state_of", Vector2i(1, 1)) == MEMORY and reveal.call("state_of", Vector2i(2, 1)) == MEMORY, "stored cells should show as memory in the first run")
	runs.call("end_run", &"test")
	var after: Node = _service(PATH)
	_check((after.get("progress") as PersistentProgress).death_count == 6 and (after.get("progress") as PersistentProgress).run_count == 4, "end of run should persist counts (deaths %d, runs %d)" % [(after.get("progress") as PersistentProgress).death_count, (after.get("progress") as PersistentProgress).run_count])
	_check((after.get("progress") as PersistentProgress).revealed_cells.get(MAP_ID, PackedVector2Array()).size() >= 2, "persisted revealed cells lost")
	after.free()

	main.queue_free()
	await process_frame
	Support.remove_file(PATH)
	_check(not FileAccess.file_exists(PATH), "temp save should be cleaned up")
	if _failures.is_empty():
		print("PASS test_save")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_save")
		quit(1)
