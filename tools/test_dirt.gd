extends SceneTree
## Headless test of the dirt walls `D` (task-070): parsing (dirt blocks light and sight); on m3_dirt in the main scene,
## walking into a dirt cell eats it (floor, collision gone, sight / light pass, chunk meshes rebuilt, crumble + crunch),
## no HIT_WALL for dirt, WALL_EATEN per eat and its world line once; the devour milestone (random gap in [100, 200],
## WALLS_DEVOURED at the milestone, a random seeded variant); the counter survives save / load; destroyed dirt comes back
## at run start; the map loads with a reachable spawn. Prints the per-chunk rebuild cost (incl. a 200 x 200 dirt map).
## Usage: godot --headless --max-fps 30 --path . -s tools/test_dirt.gd

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "dirt"
const LEGEND := "res://resources/config/map_legend.tres"
const M3 := "res://data/maps/m3_dirt.txt"
const PHASE_PLAYING := 1
const CELL_HIDDEN := 0
const CELL_SEEN := 2
const KEYBOARD: StringName = &"keyboard"
const SEED := 99
const BIG := 200
const VARIANTS: PackedStringArray = ["devour_narrator_1", "devour_narrator_2", "devour_narrator_3", "devour_narrator_4", "devour_narrator_5"]

var _failures: PackedStringArray = []
var _events: Array[StringName] = []
var _destroyed: Array[Vector2i] = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	_check_parsing()
	_check_big_chunk_cost()
	await _check_scene()
	if _failures.is_empty():
		print("PASS test_dirt")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_dirt")
		quit(1)


func _check_parsing() -> void:
	var loader := MapLoader.new()
	loader.legend = load(LEGEND) as MapLegend
	var map: MapData = loader.parse_text("#####\n#@D.#\n#####")
	_check(map.type_at(Vector2i(2, 1)) == MapLegend.DIRT, "D parses as dirt")
	_check(GlyphLightOcclusion.blocks(map, Vector2i(2, 1)), "dirt blocks light")
	_check(not SightLine.can_see(map, Vector2i(1, 1), Vector2i(3, 1), RevealConfig.new().sight_blockers, 0.0), "dirt blocks sight")
	_check(map.warnings.is_empty(), "no warnings: %s" % [map.warnings])
	map.set_type(Vector2i(2, 1), MapLegend.FLOOR)
	_check(not GlyphLightOcclusion.blocks(map, Vector2i(2, 1)), "eaten dirt passes light")
	loader.free()


## A 200 x 200 map of dirt inside a wall border: one full chunk mesh build (the cost of one destroyed cell's mesh update).
func _check_big_chunk_cost() -> void:
	var map := MapData.new()
	map.width = BIG
	map.height = BIG
	map.types.resize(BIG * BIG)
	for y in BIG:
		for x in BIG:
			map.types[y * BIG + x] = MapLegend.WALL if x == 0 or y == 0 or x == BIG - 1 or y == BIG - 1 else MapLegend.DIRT
	var cfg := DirtConfig.new()
	var builder := WorldMeshBuilder.new()
	var world := WorldConfig.new()
	var rect := Rect2i(Vector2i(4, 4) * cfg.chunk_size, Vector2i(cfg.chunk_size, cfg.chunk_size))
	map.set_type(rect.position + Vector2i(5, 5), MapLegend.FLOOR)
	var best: int = 1 << 30
	for i in 5:
		var t0: int = Time.get_ticks_usec()
		var mesh: ArrayMesh = builder.build_dirt_chunk(map, rect, world)
		best = mini(best, Time.get_ticks_usec() - t0)
		_check(mesh != null, "big chunk builds")
	print("[dirt] 200x200 map: full %dx%d chunk mesh rebuild %d us, %d triangles" % [cfg.chunk_size, cfg.chunk_size, best, builder.triangle_count()])


## Holds the movement actions so the camera-relative input points along `world_dir` on the ground.
func _press_world(rig: Node, world_dir: Vector3) -> void:
	var yaw: float = deg_to_rad(float(rig.call("current_yaw_degrees")))
	var screen: Vector3 = world_dir.rotated(Vector3.UP, -yaw)
	_release_all()
	if screen.x > 0.0:
		Input.action_press(&"move_right", screen.x)
	elif screen.x < 0.0:
		Input.action_press(&"move_left", -screen.x)
	if screen.z > 0.0:
		Input.action_press(&"move_down", screen.z)
	elif screen.z < 0.0:
		Input.action_press(&"move_up", -screen.z)


func _release_all() -> void:
	for a in [&"move_right", &"move_left", &"move_up", &"move_down"]:
		Input.action_release(a)


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
	main.get_node("IntroSequence").set("config", _fast_intro())
	var loader: MapLoader = main.get_node("World/MapLoader")
	loader.map_path = M3
	loader.use_cmdline_map = false
	root.add_child(main)
	var bus: Node = root.get_node("SignalBus")
	bus.connect("narration_event", func(e: StringName) -> void: _events.append(e))
	bus.connect("dirt_destroyed", func(_m: StringName, c: Vector2i, _cause: StringName) -> void: _destroyed.append(c))
	var runs: Node = main.get_node("RunManager")
	var guard: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 3.0:
		await create_timer(0.1).timeout
		guard += 0.1
	await create_timer(0.3).timeout
	var map: MapData = loader.data
	var dirt = main.get_node("DirtWalls")
	var view = main.get_node("DirtView")
	var sfx = main.get_node("DirtCrunchSfx")
	var narrator = main.get_node("Narrator")
	var save = main.get_node("SaveService")
	var player = main.get_node("Player")
	var world_view = main.get_node("GlyphWorldView")

	# The map.
	_check(map.errors.is_empty() and map.warnings.is_empty(), "m3 parses cleanly: %s %s" % [map.errors, map.warnings])
	_check(map.has_spawn and map.type_at(map.spawn_cell) == MapLegend.SPAWN, "m3 has a spawn")
	_check(map.teleports.size() == 2 and map.large_objects.size() == 1, "m3: one teleport pair and a gargoyle")
	_check(dirt.home_count() > 500, "m3 is mostly dirt (%d cells)" % dirt.home_count())
	_check(view.chunk_count() > 0, "dirt chunk meshes built")
	var start_left: int = dirt.count_left()

	# Walk east along the pre-dug tunnel into the dirt at its end.
	var target := Vector2i(23, 5)
	_check(map.type_at(target) == MapLegend.DIRT and map.type_at(target - Vector2i(1, 0)) == MapLegend.FLOOR, "tunnel ends in dirt at %s" % target)
	var chunk: Vector2i = dirt.chunk_of(target)
	var boxes_before: int = dirt.chunk_box_count(chunk)
	var tris_before: int = view.chunk_mesh(chunk).get_faces().size()
	runs.get("state").set("input_scheme", KEYBOARD)
	player.global_position = loader.cell_to_world(target - Vector2i(2, 0))
	_events.clear()
	var played_before: int = sfx.played
	_press_world(main.get_node("CameraRig"), Vector3.RIGHT)
	var steps: int = 0
	while map.type_at(target) == MapLegend.DIRT and steps < 120:
		await physics_frame
		steps += 1
	_check(map.type_at(target) == MapLegend.FLOOR, "walking into dirt eats it")
	_check(_destroyed.has(target), "dirt_destroyed for the eaten cell")
	_check(not _events.has(NarrationEvents.HIT_WALL), "no HIT_WALL for dirt: %s" % [_events])
	_check(_events.count(NarrationEvents.WALL_EATEN) >= 1, "WALL_EATEN fired")
	_check(dirt.chunk_box_count(chunk) != boxes_before or dirt.count_left() < start_left, "collision chunk rebuilt")
	_check(view.chunk_mesh(chunk).get_faces().size() != tris_before, "chunk mesh rebuilt")
	_check(view.crumbling() > 0, "the crumble runs")
	_check(sfx.played > played_before and sfx.stream() is AudioStreamWAV, "crunch played (synthesized)")
	_check(not GlyphLightOcclusion.blocks(map, target) and not GlyphVisibilityMap.is_solid(map.type_at(target)), "light passes the eaten cell")
	_check(SightLine.can_see(map, target - Vector2i(1, 0), target + Vector2i(1, 0), RevealConfig.new().sight_blockers, 0.0) or map.type_at(target + Vector2i(1, 0)) == MapLegend.DIRT, "sight passes the eaten cell")
	# Keep digging: the body passes through and eats on (Boulder Dash).
	var dug_more: bool = false
	steps = 0
	while steps < 90:
		await physics_frame
		steps += 1
		if map.type_at(target + Vector2i(2, 0)) == MapLegend.FLOOR:
			dug_more = true
			break
	_release_all()
	_check(dug_more, "the body digs on through the next cells")
	_check(loader.world_to_cell(player.global_position).x >= target.x, "the body moved into the eaten cell (at %s)" % loader.world_to_cell(player.global_position))
	_check(not _events.has(NarrationEvents.HIT_WALL), "still no HIT_WALL while digging")
	# The world line is never lost (task-087): it waits behind the lines before it and then plays; later eats repeat it
	# only on the repeat roll.
	for i in 1200:
		narrator.advance(0.1)
	_check(narrator.is_heard("dirt_world_crumble"), "world line 'Crumble, dust, destroyed' heard")
	_check(narrator.hearings("dirt_world_crumble") >= 1, "the world line counts its hearings for the repeat ladder")
	_check(world_view.visibility() != null, "world view still fine")

	# Destroying a non-dirt cell is refused.
	_check(not dirt.destroy(map.spawn_cell), "destroy refuses a non-dirt cell")

	# Milestones: seeded gap in [100, 200], WALLS_DEVOURED exactly there, re-rolled.
	var p: PersistentProgress = save.progress
	p.walls_eaten = 0
	p.next_devour_at = 0
	dirt.rng.seed = SEED
	_events.clear()
	var cells: Array[Vector2i] = []
	for y in map.height:
		for x in map.width:
			if map.type_at(Vector2i(x, y)) == MapLegend.DIRT:
				cells.append(Vector2i(x, y))
	var fired_at: Array[int] = []
	var cost_total: int = 0
	var cost_n: int = 0
	var first_gap: int = -1
	for c in cells:
		var t0: int = Time.get_ticks_usec()
		dirt.destroy(c)
		cost_total += Time.get_ticks_usec() - t0
		cost_n += 1
		if first_gap < 0:
			first_gap = p.next_devour_at
		if _events.has(NarrationEvents.WALLS_DEVOURED):
			fired_at.append(p.walls_eaten)
			_events.clear()
			if fired_at.size() == 2:
				break
	print("[dirt] m3: destroy() incl. collision chunk, chunk meshes, light and reveal updates: %d us average over %d cells" % [cost_total / maxi(cost_n, 1), cost_n])
	_check(first_gap >= 100 and first_gap <= 200, "first milestone gap in [100, 200]: %d" % first_gap)
	_check(fired_at.size() == 2, "two milestones reached (%s)" % [fired_at])
	if fired_at.size() == 2:
		_check(fired_at[0] == first_gap, "WALLS_DEVOURED at the milestone (%d vs %d)" % [fired_at[0], first_gap])
		var gap2: int = fired_at[1] - fired_at[0]
		_check(gap2 >= 100 and gap2 <= 200, "re-rolled gap in [100, 200]: %d" % gap2)
	_check(p.next_devour_at - p.walls_eaten >= 100 and p.next_devour_at - p.walls_eaten <= 200, "next milestone stored")

	# Random variant, seeded and repeatable.
	narrator.rng.seed = SEED
	var picks: Array[String] = []
	for i in 20:
		var beat: NarrationBeat = narrator.pick_for_event(NarrationEvents.WALLS_DEVOURED)
		picks.append(beat.id if beat != null else "none")
	narrator.rng.seed = SEED
	var again: Array[String] = []
	for i in 20:
		var beat: NarrationBeat = narrator.pick_for_event(NarrationEvents.WALLS_DEVOURED)
		again.append(beat.id if beat != null else "none")
	var distinct: Dictionary = {}
	for id in picks:
		distinct[id] = true
		_check(VARIANTS.has(id), "pick %s is one of the 5 variants" % id)
	_check(distinct.size() >= 3, "random variants differ (%s)" % [distinct.keys()])
	_check(picks == again, "seeded picks repeat")
	var beat: NarrationBeat = narrator.pick_for_event(NarrationEvents.WALLS_DEVOURED)
	_check(beat != null and beat.layer == NarrationBeat.Layer.NARRATOR and not beat.once, "devour lines are narrator lines, not once")
	_check(narrator.config.ttl_exempt_events.has(NarrationEvents.WALLS_DEVOURED), "WALLS_DEVOURED is ttl-exempt")

	# The counter survives save / load.
	var eaten: int = p.walls_eaten
	var next: int = p.next_devour_at
	save.save_progress()
	save.load_progress()
	_check(save.progress.walls_eaten == eaten and save.progress.next_devour_at == next, "counter persists (%d/%d vs %d/%d)" % [save.progress.walls_eaten, save.progress.next_devour_at, eaten, next])

	# Run start: destroyed dirt is back.
	dirt.restore()
	_check(dirt.count_left() == dirt.home_count() and map.type_at(target) == MapLegend.DIRT, "destroyed dirt restored")
	_check(GlyphLightOcclusion.blocks(map, target), "restored dirt blocks light again")

	main.queue_free()
	await process_frame
	Support.remove_file(save_path)
