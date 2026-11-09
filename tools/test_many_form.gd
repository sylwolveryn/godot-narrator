extends SceneTree
## Headless test of task-090: the many form's body radius (from the formation), the fit check before switching
## (refused next to walls with FORM_BLOCKED, allowed in an open spot), the whole-body collision radius, and the larger
## zoom limit of the many form.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_many_form.gd

const Support := preload("res://tools/test_support.gd")
const MAP := "res://data/maps/m6_teleporters.txt"
const PHASE_PLAYING := 1

var _failures: PackedStringArray = []
var _events: Array[StringName] = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


## A floor cell with only floor within `reach` cells, or (-1, -1).
func _open_cell(map: MapData, reach: int) -> Vector2i:
	for y in range(reach, map.height - reach):
		for x in range(reach, map.width - reach):
			var ok: bool = true
			for dy in range(-reach, reach + 1):
				for dx in range(-reach, reach + 1):
					var t: StringName = map.type_at(Vector2i(x + dx, y + dy))
					if t != MapLegend.FLOOR and t != MapLegend.SPAWN:
						ok = false
						break
					if map.large_object_at(Vector2i(x + dx, y + dy)) != null or map.objects.has(Vector2i(x + dx, y + dy)):
						ok = false
						break
				if not ok:
					break
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## A floor cell next to a wall, or (-1, -1).
func _cell_by_wall(map: MapData) -> Vector2i:
	for y in range(1, map.height - 1):
		for x in range(1, map.width - 1):
			if map.type_at(Vector2i(x, y)) == MapLegend.FLOOR and map.type_at(Vector2i(x + 1, y)) == MapLegend.WALL:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var save_path: String = Support.isolate_save(main, "many_form")
	var seeded := PersistentProgress.new()
	seeded.identity_glyph = "Q"
	seeded.death_count = 5
	seeded.run_count = 5
	seeded.entity_unlocked = true
	seeded.entity_grow_played = true
	seeded.entity_form = "single"
	ResourceSaver.save(seeded, save_path)
	var loader = main.get_node("World/MapLoader")
	loader.map_path = MAP
	loader.use_cmdline_map = false
	root.add_child(main)
	root.get_node("SignalBus").connect(&"narration_event", func(e: StringName) -> void: _events.append(e))
	var runs = main.get_node("RunManager")
	var guard: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 5.0:
		await create_timer(0.1).timeout
		guard += 0.1
	var entity = main.get_node("EntityProgression")
	var player = main.get_node("Player")
	var rig = main.get_node("CameraRig")
	var radius: float = entity.body_radius(EntityForm.GROWN)
	# Task-099: the human many form is about 2 tiles wide and 3 tall.
	var ext_grown: Vector2 = entity.body_extents(EntityForm.GROWN)
	_check(radius > 0.8 and radius < 1.2 and ext_grown.y > 1.3 and ext_grown.y < 1.7, "grown body ~2 x 3 tiles from the human formation (%s)" % ext_grown)
	_check(entity.body_radius(EntityForm.SINGLE) == 0.0, "the single form has no own radius")
	_check(is_equal_approx(player.body_radius(), player.config.body_radius), "single form: the small capsule")

	var map: MapData = loader.data
	var by_wall: Vector2i = _cell_by_wall(map)
	_check(by_wall.x >= 0, "the map has a floor cell by a wall")
	player.global_position = loader.cell_to_world(by_wall)
	await physics_frame
	await physics_frame
	_events.clear()
	_check(not entity.fits(EntityForm.GROWN), "next to a wall the grown body does not fit")
	_check(not entity.set_form(EntityForm.GROWN), "the switch is refused there")
	_check(entity.current_form() == EntityForm.SINGLE, "the form stays single")
	_check(_events.has(NarrationEvents.FORM_BLOCKED), "the refusal narrates FORM_BLOCKED")

	var open: Vector2i = _open_cell(map, ceili(radius) + 1)
	if open.x < 0:
		print("NOTE: the map has no spot open enough for the grown body; open-spot checks skipped")
	else:
		player.global_position = loader.cell_to_world(open)
		await physics_frame
		await physics_frame
		var limit_single: float = rig.zoom_limit()
		_check(entity.fits(EntityForm.GROWN), "an open spot fits the grown body")
		_check(entity.set_form(EntityForm.GROWN), "the switch works there")
		await process_frame
		_check(is_equal_approx(player.body_radius(), radius), "grown form: the whole body collides (%s)" % player.body_radius())
		var shape: CapsuleShape3D = player.get_node("Collision").shape
		var ext: Vector2 = entity.body_extents(EntityForm.GROWN)
		_check(is_equal_approx(shape.radius, minf(ext.x, ext.y)) and is_equal_approx(shape.height, maxf(ext.x, ext.y) * 2.0), "the lying capsule takes the body outline (task-094)")
		_check(rig.zoom_limit() > limit_single * 1.5, "the many form zooms out further (%s vs %s)" % [rig.zoom_limit(), limit_single])
		_check(entity.set_form(EntityForm.SINGLE), "back to single always works")
		await process_frame
		_check(is_equal_approx(shape.radius, player.config.body_radius), "single again: the small capsule")
		_check(is_equal_approx(rig.zoom_limit(), limit_single), "single again: the normal zoom limit")

	main.queue_free()
	await process_frame
	Support.remove_file(save_path)
	if _failures.is_empty():
		print("PASS test_many_form")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_many_form")
		quit(1)
