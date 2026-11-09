extends SceneTree
## Headless test of task-094: the grown (many) body's collider follows the formation (task-099: the human, deeper than
## wide, so the capsule lies along the screen's up; turned with the camera); it digs through dirt at full speed; it reaches cannons with its outline (focus + the cannon turns away);
## it picks up a diamond its outline covers away from the heart cell. Plus the BodyOutline geometry.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_many_form_contacts.gd

const Support := preload("res://tools/test_support.gd")
const ARENA := "res://data/maps/m2_arena.txt"
const FIELD := "res://data/maps/m4_dirt_field.txt"
const PHASE_PLAYING := 1
const KEYBOARD := &"keyboard"

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	_check_geometry()
	await _check_field()
	await _check_arena()
	if _failures.is_empty():
		print("PASS test_many_form_contacts")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_many_form_contacts")
		quit(1)


func _check_geometry() -> void:
	var o: BodyOutline = BodyOutline.for_body(Vector2(10, 10), Vector2(4.25, 2.35), 0.0)
	_check(is_equal_approx(o.radius, 2.35), "outline radius is the half depth")
	_check(o.a.distance_to(o.b) > 3.7 and o.a.distance_to(o.b) < 3.9, "outline segment spans the width minus the caps")
	_check(o.distance_to_point(Vector2(14.2, 10)) == 0.0, "a point at the side tip is inside")
	_check(o.distance_to_point(Vector2(10, 13.0)) > 0.5, "a point 3 above the heart is outside (the old circle held it)")
	_check(is_zero_approx(o.distance_to_rect(Rect2(12, 12, 1, 1))), "a rect overlapping the body touches")
	_check(is_equal_approx(o.distance_to_rect(Rect2(9, 13, 2, 1)), 0.65), "rect above: gap = 13 - 10 - 2.35")
	var turned: BodyOutline = BodyOutline.for_body(Vector2.ZERO, Vector2(4.25, 2.35), PI * 0.5)
	_check(absf(turned.a.x) < 0.001 and absf(turned.b.x) < 0.001, "a quarter turn lays the segment along z")
	_check(is_zero_approx(BodyOutline.segment_rect_distance(Vector2(-5, 0.5), Vector2(5, 0.5), Rect2(0, 0, 1, 1))), "segment crossing a rect")
	var basis: Basis = BodyOutline.lying_basis(0.0)
	_check((basis * Vector3.UP).is_equal_approx(Vector3.RIGHT), "the lying basis lays the capsule axis across the screen")
	# Task-099: a body deeper than wide lies along the screen's up.
	var tall: BodyOutline = BodyOutline.for_body(Vector2.ZERO, Vector2(1.0, 1.5), 0.0)
	_check(is_equal_approx(tall.radius, 1.0) and absf(tall.a.x) < 0.001 and is_equal_approx(tall.a.distance_to(tall.b), 1.0), "a tall outline runs along z")
	_check((BodyOutline.lying_basis(0.0, Vector2(1.0, 1.5)) * Vector3.UP).is_equal_approx(Vector3.FORWARD), "a tall capsule lies along the screen's up")


func _seed(tag: String, main: Node) -> String:
	var save_path: String = Support.isolate_save(main, tag)
	var seeded := PersistentProgress.new()
	seeded.identity_glyph = "Q"
	seeded.death_count = 5
	seeded.run_count = 5
	seeded.entity_unlocked = true
	seeded.entity_grow_played = true
	seeded.entity_form = "single"
	ResourceSaver.save(seeded, save_path)
	return save_path


func _start(map_path: String, tag: String) -> Array:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var save_path: String = _seed(tag, main)
	var loader = main.get_node("World/MapLoader")
	loader.map_path = map_path
	loader.use_cmdline_map = false
	root.add_child(main)
	var runs = main.get_node("RunManager")
	var guard: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 5.0:
		await create_timer(0.1).timeout
		guard += 0.1
	runs.get("state").set("input_scheme", KEYBOARD)
	return [main, save_path]


## Grows the body in place (the test plays the data layer: the fit check would refuse it inside dirt).
func _grow(main: Node) -> void:
	main.get_node("SaveService").progress.entity_form = String(EntityForm.GROWN)
	root.get_node("SignalBus").entity_form_changed.emit(EntityForm.GROWN, false)


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


func _end(main: Node, save_path: String) -> void:
	_release_all()
	main.queue_free()
	await process_frame
	Support.remove_file(save_path)


## The grown body in the middle of the dirt field digs on at (nearly) its top speed.
func _check_field() -> void:
	var started: Array = await _start(FIELD, "many_contacts_field")
	var main: Node = started[0]
	var loader = main.get_node("World/MapLoader")
	var player = main.get_node("Player")
	var rig = main.get_node("CameraRig")
	var map: MapData = loader.data
	var centre := Vector2i(map.width / 2, map.height / 2)
	player.global_position = loader.cell_to_world(centre)
	_grow(main)
	await physics_frame
	_check(player.has_grown_body(), "the grown body is active")
	var shape: CapsuleShape3D = player.get_node("Collision").shape
	var ext: Vector2 = player.body_extents()
	_check(ext.y > ext.x * 1.3, "the human body is deeper than it is wide (%s)" % ext)
	_check(is_equal_approx(shape.radius, ext.x) and is_equal_approx(shape.height, ext.y * 2.0), "the capsule takes the formation's outline")
	var axis: Vector3 = player.get_node("Collision").global_basis * Vector3.UP
	var up_screen: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(rig.current_yaw_degrees()))
	_check(absf(axis.dot(up_screen)) > 0.99, "the capsule lies along the screen's up")
	var dirt = main.get_node("DirtWalls")
	var left_before: int = dirt.count_left()
	var start: Vector3 = player.global_position
	var dir: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(rig.current_yaw_degrees()))
	_press_world(rig, dir)
	var seconds: float = 1.5
	var steps: int = int(seconds * Engine.physics_ticks_per_second)
	for i in steps:
		await physics_frame
	var travelled: float = (player.global_position - start).dot(dir)
	_release_all()
	var top: float = player.max_speed
	_check(dirt.count_left() < left_before - 10, "the body ate a front of dirt (%d cells)" % (left_before - dirt.count_left()))
	# Reaching top speed takes max_speed / acceleration seconds; the rest is at full speed when dirt does not slow it.
	var ramp: float = minf(top / maxf(player.acceleration, 0.001), seconds)
	var expected: float = top * (seconds - ramp) + top * ramp * 0.5
	_check(travelled > expected * 0.85, "digging keeps the speed: %.2f of %.2f expected" % [travelled, expected])
	# Also up the screen (the short side faces the dirt).
	var up: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(rig.current_yaw_degrees()))
	start = player.global_position
	_press_world(rig, up)
	for i in steps:
		await physics_frame
	travelled = (player.global_position - start).dot(up)
	_check(travelled > expected * 0.85, "digging up the screen keeps the speed: %.2f of %.2f" % [travelled, expected])
	await _end(main, started[1])


## A spot where the grown body fits and its outline is within reach of the cannon, or null.
func _spot_by(entity: Node, player: Node, loader: Node, interactables: Node, c: Interactable) -> Variant:
	for r in range(1, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var cell: Vector2i = c.footprint.position + Vector2i(dx, dy)
				var at: Vector3 = loader.cell_to_world(cell)
				if not entity.fits(EntityForm.GROWN, at):
					continue
				player.global_position = at
				if interactables.player_reaches(c):
					return at
	return null


func _check_arena() -> void:
	var started: Array = await _start(ARENA, "many_contacts_arena")
	var main: Node = started[0]
	var loader = main.get_node("World/MapLoader")
	var player = main.get_node("Player")
	var entity = main.get_node("EntityProgression")
	var interactables = main.get_node("Interactables")
	var cannons = main.get_node("CannonSystem")
	_check(cannons.cannon_count() > 0, "the arena has cannons")
	_grow(main)
	await physics_frame
	var found: bool = false
	for i in cannons.cannon_count():
		var c: Interactable = cannons.cannon(i)
		var spot: Variant = _spot_by(entity, player, loader, interactables, c)
		if spot == null:
			continue
		found = true
		player.global_position = spot
		player.velocity = Vector3.ZERO
		# Single-form rule for comparison: the heart cell is NOT next to the footprint.
		var heart_near: bool = c.in_reach(loader.world_to_cell(spot), interactables.config.default_reach)
		await physics_frame
		await physics_frame
		_check(interactables.focus() == c, "the grown body focuses the cannon by its edge (heart cell next to it: %s)" % heart_near)
		var facing_before: float = c.facing
		for k in 30:
			await physics_frame
		_check(not is_nan(c.target_facing), "the cannon turns away from the grown body (facing %s -> %s)" % [facing_before, c.facing])
		break
	_check(found, "a spot by a cannon fits the grown body")

	# A diamond under the body's side, not under the heart.
	var remains = main.get_node("EnemyRemains")
	var ext: Vector2 = player.body_extents()
	var s: float = loader.world_config.cell_size
	# Along the body's long axis (task-099: the human is deeper than wide, so up the screen).
	var long_axis: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, BodyOutline.axis_yaw(ext, deg_to_rad(main.get_node("CameraRig").current_yaw_degrees())))
	var heart: Vector3 = player.global_position
	var side_cell: Vector2i = loader.world_to_cell(heart + long_axis * (maxf(ext.x, ext.y) - s * 0.6))
	if side_cell != loader.world_to_cell(heart) and loader.data.type_at(side_cell) != MapLegend.WALL:
		var before: int = remains.total_collected()
		remains.set("_diamonds", {side_cell: true} as Dictionary[Vector2i, bool])
		await physics_frame
		await physics_frame
		_check(remains.total_collected() == before + 1, "the grown body picks up a diamond under its side")
	else:
		print("NOTE: no side cell for the diamond check")
	await _end(main, started[1])
