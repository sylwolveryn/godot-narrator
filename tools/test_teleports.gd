extends SceneTree
## Headless test of the teleports (task-068): parsing (only an exact 3x3 T ring around a channel character works; 2x3,
## a wrong centre, a ring touching another T are broken; a centre `o` is a channel), the destination rule (next higher
## channel present, wrapping; random among its pads; nothing without another channel) and the trip on the arena in the
## main scene (movement and menu blocked, ~3 s, ends on a candidate centre, no immediate re-trigger, camera override
## released, zoom-out only with several candidates, arrival wave x candidates).
## Usage: godot --headless --max-fps 30 --path . -s tools/test_teleports.gd

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "teleports"
const LEGEND := "res://resources/config/map_legend.tres"
const ARENA := "res://data/maps/m2_arena.txt"
const PHASE_PLAYING := 1
const KEYBOARD: StringName = &"keyboard"
## Slack on the measured trip time (seconds; physics steps and signal order).
const TIME_SLACK := 0.15
const ZOOM_EPS := 0.01
const SEED := 4242

var _failures: PackedStringArray = []
var _started_at: int = -1
var _finished_at: int = -1
var _started_candidates: int = 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _run() -> void:
	_check_parsing()
	_check_targets()
	await _check_scene()
	if _failures.is_empty():
		print("PASS test_teleports")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_teleports")
		quit(1)


func _parse(loader: MapLoader, text: String) -> MapData:
	var width: int = 0
	for line in text.split("\n"):
		width = maxi(width, line.length())
	return loader.parse_text(text + "\n" + "@".rpad(width, "."))


func _check_parsing() -> void:
	var loader := MapLoader.new()
	loader.legend = load(LEGEND) as MapLegend
	var map: MapData = _parse(loader, "TTT\nT0T\nTTT")
	_check(map.teleports.size() == 1 and map.broken_teleports.is_empty(), "exact ring is one working pad")
	if map.teleports.size() == 1:
		var pad: TeleportPad = map.teleports[0]
		_check(pad.centre == Vector2i(1, 1) and pad.channel == "0" and pad.channel_index == 0 and pad.rect == Rect2i(0, 0, 3, 3), "pad centre / channel / rect")
	_check(map.warnings.is_empty() and map.errors.is_empty(), "a ring parses cleanly: %s %s" % [map.warnings, map.errors])
	var all_floor: bool = true
	for y in 3:
		for x in 3:
			all_floor = all_floor and map.type_at(Vector2i(x, y)) == MapLegend.FLOOR
	_check(all_floor, "ring and centre cells are floor")

	map = _parse(loader, "TT\nTT\nTT")
	_check(map.teleports.is_empty() and map.broken_teleports.size() == 1, "2x3 is broken")
	_check(map.type_at(Vector2i(1, 2)) == MapLegend.FLOOR, "broken T cells are floor")
	map = _parse(loader, "TTT\nT#T\nTTT")
	_check(map.teleports.is_empty() and map.broken_teleports.size() == 1, "ring with a wall centre is broken")
	_check(map.type_at(Vector2i(1, 1)) == MapLegend.WALL, "the centre of a broken ring keeps its legend meaning")
	map = _parse(loader, "TTT\nT.T\nTTT")
	_check(map.teleports.is_empty() and map.broken_teleports.size() == 1, "ring with a floor centre is broken")
	map = _parse(loader, "TTT\nTTT\nTTT")
	_check(map.teleports.is_empty() and map.broken_teleports.size() == 1, "filled 3x3 is broken")
	map = _parse(loader, "TTTT\nT0T.\nTTT.")
	_check(map.teleports.is_empty() and map.broken_teleports.size() == 1, "ring touching another T is broken")
	map = _parse(loader, "TTT.\nT0T.\nTTT.\n...T")
	_check(map.teleports.is_empty() and map.broken_teleports.size() == 1, "ring touching a T diagonally is broken")
	map = _parse(loader, "TTTTT\nT0T1T\nTTTTT")
	_check(map.teleports.is_empty(), "two rings sharing a column of T are broken")
	map = _parse(loader, "TT.\nT.T\nTTT")
	_check(map.teleports.is_empty() and map.broken_teleports.size() == 1, "ring with a missing corner is broken")
	map = _parse(loader, "TTT.TTT\nToT.TZT\nTTT.TTT")
	_check(map.teleports.size() == 2 and map.broken_teleports.is_empty(), "two separate rings")
	if map.teleports.size() == 2:
		_check(map.teleports[0].channel == "o" and map.teleports[1].channel == "Z" and map.teleports[1].channel_index == 61, "channels o and Z")
	_check(map.objects.is_empty(), "an o inside a ring is a channel, not a pushable object")
	_check(map.warnings.is_empty(), "no warnings for rings: %s" % [map.warnings])
	_check(map.teleport_at_centre(Vector2i(5, 1)) == 1 and map.teleport_at_centre(Vector2i(0, 0)) == -1, "teleport_at_centre")
	loader.free()


func _pads(channels: String) -> Array[TeleportPad]:
	var all: String = (load(LEGEND) as MapLegend).teleport_channels
	var out: Array[TeleportPad] = []
	for ch in channels:
		var pad := TeleportPad.new()
		pad.broken = false
		pad.channel = ch
		pad.channel_index = all.find(ch)
		out.append(pad)
	return out


func _ints(values: Array) -> Array[int]:
	var out: Array[int] = []
	for v in values:
		out.append(int(v))
	return out


func _check_targets() -> void:
	var pads: Array[TeleportPad] = _pads("00077777")
	var from0: Array[int] = TeleportPad.targets(pads, 0)
	_check(from0 == _ints([3, 4, 5, 6, 7]), "0 -> the five 7s, got %s" % [from0])
	var from7: Array[int] = TeleportPad.targets(pads, 5)
	_check(from7 == _ints([0, 1, 2]), "7 -> the three 0s (wrap), got %s" % [from7])
	_check(TeleportPad.targets(_pads("000"), 1).is_empty(), "same channel only -> nowhere")
	_check(TeleportPad.targets(_pads("5"), 0).is_empty(), "single pad -> nowhere")
	_check(TeleportPad.targets(_pads("0aZ"), 2) == _ints([0]), "Z wraps to 0")
	_check(TeleportPad.targets(_pads("0aZ"), 1) == _ints([2]), "a -> Z (next higher)")
	_check(TeleportPad.targets(_pads("3b"), 0) == _ints([1]) and TeleportPad.targets(_pads("3b"), 1) == _ints([0]), "two channels go to each other")
	_check(TeleportPad.targets(_pads("19A7"), 0) == _ints([3]), "1 -> 7 skips nothing lower")


func _fast_intro() -> IntroConfig:
	var cfg := IntroConfig.new()
	cfg.black_hold = 0.05
	cfg.wave_fade_in = 0.05
	cfg.wave_hold = 0.05
	cfg.reveal_duration = 0.05
	return cfg


func _check_scene() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var save_path: String = Support.isolate_save(main, SAVE_TAG)
	var seeded := PersistentProgress.new()
	seeded.identity_glyph = "Q"
	seeded.run_count = 1
	seeded.death_count = 1
	seeded.menu_unlocked = true
	ResourceSaver.save(seeded, save_path)
	main.get_node("IntroSequence").set("config", _fast_intro())
	var loader: MapLoader = main.get_node("World/MapLoader")
	loader.map_path = ARENA
	loader.use_cmdline_map = false
	root.add_child(main)
	var runs: Node = main.get_node("RunManager")
	var guard: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 3.0:
		await _wait(0.1)
		guard += 0.1
	await _wait(0.3)
	var map: MapData = loader.data
	_check(map.teleports.size() == 6 and map.broken_teleports.size() == 1, "arena: 6 working pads, 1 broken (got %d, %d)" % [map.teleports.size(), map.broken_teleports.size()])
	var system: Node = main.get_node("TeleportSystem")
	var view: Node = main.get_node("TeleportView")
	var rig: Node = main.get_node("CameraRig")
	var menu: Node = main.get_node("MenuController")
	var player: CharacterBody3D = main.get_node("Player")
	var glyph: Node = main.get_node("PlayerGlyphView")
	_check(view.call("piece_count") == 7, "one view piece per pad (got %d)" % view.call("piece_count"))
	(system.get("rng") as RandomNumberGenerator).seed = SEED
	var bus: Node = root.get_node("SignalBus")
	bus.connect("teleport_started", func(_f: Vector3, c: Array[Vector3], _i: int, _d: float) -> void:
		_started_at = Time.get_ticks_msec()
		_started_candidates = c.size())
	bus.connect("teleport_finished", func() -> void: _finished_at = Time.get_ticks_msec())
	runs.get("state").set("input_scheme", KEYBOARD)
	var cfg: TeleportConfig = load("res://resources/config/teleport_config.tres")
	var zoom_max: float = (rig.get("view_config") as CameraViewConfig).zoom_max

	# Trip 1: channel 0 (beside the spawn) -> channel 1, a single candidate.
	var pad0: int = _pad_of(map, "0", 0)
	var pad1: int = _pad_of(map, "1", 0)
	player.global_position = loader.cell_to_world(map.teleports[pad0].centre)
	await _trip_and_check(system, view, rig, menu, player, glyph, map, cfg, 1, [pad1] as Array[int], zoom_max)
	# Standing on the arrival centre does not fire again.
	await _wait(0.6)
	_check(not system.call("is_active"), "no re-trigger while standing on the arrival centre")
	# Leave and come back: pad 1 -> channel 7, three candidates (zoom-out ping-pong).
	player.global_position = loader.cell_to_world(map.teleports[pad1].centre + Vector2i(2, 0))
	await _wait(0.2)
	await _waves_gone(view)
	var sevens: Array[int] = []
	for i in map.teleports.size():
		if map.teleports[i].channel == "7":
			sevens.append(i)
	player.global_position = loader.cell_to_world(map.teleports[pad1].centre)
	await _trip_and_check(system, view, rig, menu, player, glyph, map, cfg, 3, sevens, zoom_max)
	# Pad 7 -> channel 0, two candidates.
	var here: Vector2i = loader.world_to_cell(player.global_position)
	player.global_position = loader.cell_to_world(here + Vector2i(0, 2))
	await _wait(0.2)
	await _waves_gone(view)
	player.global_position = loader.cell_to_world(here)
	var zeros: Array[int] = [pad0, _pad_of(map, "0", 1)]
	await _trip_and_check(system, view, rig, menu, player, glyph, map, cfg, 2, zeros, zoom_max)

	main.queue_free()
	await process_frame
	Support.remove_file(save_path)


## Waits until the waves of the last trip have faded (so the next trip's arrival scale is measured alone).
func _waves_gone(view: Node) -> void:
	var guard: int = 0
	while int(view.call("wave_count")) > 0 and guard < 300:
		await process_frame
		guard += 1


func _pad_of(map: MapData, channel: String, nth: int) -> int:
	var seen: int = 0
	for i in map.teleports.size():
		if map.teleports[i].channel == channel:
			if seen == nth:
				return i
			seen += 1
	return -1


func _trip_and_check(system: Node, view: Node, rig: Node, menu: Node, player: CharacterBody3D, glyph: Node, map: MapData,
		cfg: TeleportConfig, count: int, expected: Array[int], zoom_max: float) -> void:
	var what: String = "trip with %d candidate(s)" % count
	_started_at = -1
	_finished_at = -1
	var zoom0: float = rig.call("current_zoom")
	var guard: int = 0
	while not system.call("is_active") and guard < 10:
		await physics_frame
		guard += 1
	_check(system.call("is_active"), "%s: started" % what)
	_check(player.call("is_teleporting"), "%s: player blocked" % what)
	_check(_started_candidates == count and system.call("candidate_pads") == expected, "%s: candidates %s, expected %s" % [what, system.call("candidate_pads"), expected])
	var dest: int = system.call("destination_pad")
	_check(expected.has(dest), "%s: destination is a candidate" % what)
	# Movement input is ignored and the menu stays shut during the trip.
	Input.action_press(&"move_right")
	await _wait(cfg.glow_in_seconds * 0.5)
	_check(int(view.call("wave_count")) > 0, "%s: glow-in waves on the world material" % what)
	_check(player.velocity.length() < 0.001, "%s: body does not move (v %s)" % [what, player.velocity])
	_check(not menu.call("open") and not menu.call("is_open"), "%s: menu refused during the trip" % what)
	var max_zoom: float = 0.0
	var max_scale: float = 0.0
	var hidden: bool = false
	var overridden: bool = false
	while system.call("is_active"):
		await process_frame
		max_zoom = maxf(max_zoom, rig.call("current_zoom"))
		max_scale = maxf(max_scale, view.call("max_wave_scale"))
		hidden = hidden or float(glyph.call("teleport_presence")) <= 0.0
		overridden = overridden or rig.call("is_overridden")
		if system.call("is_active"):
			_check(player.velocity.length() < 0.001, "%s: body still during the trip" % what)
	Input.action_release(&"move_right")
	var seconds: float = (_finished_at - _started_at) / 1000.0
	_check(absf(seconds - cfg.trip_seconds) <= TIME_SLACK, "%s: lasted %.2f s (want %.2f)" % [what, seconds, cfg.trip_seconds])
	var cell: Vector2i = (player.get_parent().get_node("World/MapLoader") as MapLoader).world_to_cell(player.global_position)
	_check(cell == map.teleports[dest].centre, "%s: player ends on the chosen centre (%s vs %s)" % [what, cell, map.teleports[dest].centre])
	_check(overridden and not rig.call("is_overridden"), "%s: camera overridden during, released after" % what)
	_check(hidden, "%s: player glyph hidden during the travel" % what)
	_check(not player.call("is_teleporting"), "%s: movement free again" % what)
	if count > 1:
		_check(absf(max_zoom - zoom_max) < ZOOM_EPS, "%s: zoomed out fully (%.2f vs %.2f)" % [what, max_zoom, zoom_max])
	else:
		_check(max_zoom <= zoom0 + ZOOM_EPS, "%s: no zoom-out (%.2f vs %.2f)" % [what, max_zoom, zoom0])
	_check(absf(max_scale - minf(float(count), cfg.max_candidate_multiplier)) < 0.001, "%s: arrival wave x %d (got %.2f)" % [what, count, max_scale])
	_check(menu.call("open"), "%s: menu opens again after the trip" % what)
	menu.call("close")
