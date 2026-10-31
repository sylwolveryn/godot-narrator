extends SceneTree
## Headless test of the in-world player glyph and the halo field (task-033) on the real main scene:
## one halo per item/spike/corruption cell, the glyph is shown after spawn, erosion raises its shown level,
## shedding and death make fragments, the glyph hides at the burst and returns with the next run.
## Usage: godot --headless --path . -s tools/test_player_glyph.gd

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "player_glyph"
const PHASE_PLAYING := 1

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _first_cell(loader: MapLoader, type: StringName) -> Vector2i:
	for y in loader.data.height:
		for x in loader.data.width:
			if loader.data.type_at(Vector2i(x, y)) == type:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	Support.isolate_save(main, SAVE_TAG)
	var intro := IntroConfig.new()
	intro.black_hold = 0.05
	intro.wave_fade_in = 0.05
	intro.wave_hold = 0.05
	intro.reveal_duration = 0.05
	main.get_node("IntroSequence").set("config", intro)
	var run_cfg: RunConfig = (main.get_node("RunManager").get("config") as RunConfig).duplicate()
	run_cfg.restart_delay = 1.5
	main.get_node("RunManager").set("config", run_cfg)
	root.add_child(main)
	var view: Node = main.get_node("PlayerGlyphView")
	var halos: Node = main.get_node("GlyphHaloField")
	var runs: Node = main.get_node("RunManager")
	var player: CharacterBody3D = main.get_node("Player")
	var loader: MapLoader = main.get_node("World/MapLoader")

	var expected: int = 0
	for y in loader.data.height:
		for x in loader.data.width:
			var type: StringName = loader.data.type_at(Vector2i(x, y))
			if type == MapLegend.ITEM or type == MapLegend.SPIKES or type == MapLegend.CORRUPT:
				expected += 1
	_check(expected > 0 and halos.call("halo_count") == expected, "halo count %d, expected %d" % [halos.call("halo_count"), expected])

	await _wait(0.4)
	_check(runs.get("phase") == PHASE_PLAYING, "run should be playing")
	_check(view.call("is_glyph_visible") and view.call("identity_text") == str(player.get("identity_glyph")), "glyph should be shown with the identity")
	_check(view.call("shown_level") == 0.0 and view.call("fragment_count") == 0, "fresh run: no erosion, no fragments")

	# Erosion: slow corruption (rate lowered so it does not kill), the shown level rises, fragments are shed.
	var corrupt_def: HazardDefinition = loader.legend.hazards.get(MapLegend.CORRUPT)
	corrupt_def.erosion_rate = 1.0
	corrupt_def.erosion_threshold = 3.0
	var corrupt_cell: Vector2i = _first_cell(loader, MapLegend.CORRUPT)
	player.velocity = Vector3.ZERO
	player.global_position = loader.cell_to_world(corrupt_cell)
	await _wait(2.0)
	_check(view.call("shown_level") > 0.3, "erosion should raise the shown level, got %f" % view.call("shown_level"))
	_check(view.call("fragment_count") > 0, "eroding past the threshold should shed a fragment")
	_check(view.call("is_glyph_visible"), "glyph stays while eroding")

	# Death: the glyph bursts into fragments, the next run brings it back.
	await _wait(1.5)
	_check(not view.call("is_glyph_visible"), "glyph should be gone after the burst")
	_check(view.call("fragment_count") >= 1, "death should leave fragments")
	var guard: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 4.0:
		await _wait(0.1)
		guard += 0.1
	await _wait(0.2)
	_check(view.call("is_glyph_visible") and view.call("fragment_count") == 0, "next run: glyph back, fragments cleared")
	_check(view.call("shown_level") == 0.0, "next run: erosion cleared")

	main.queue_free()
	await process_frame
	Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
	if _failures.is_empty():
		print("PASS test_player_glyph")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_player_glyph")
		quit(1)
