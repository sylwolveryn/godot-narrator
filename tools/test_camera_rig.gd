extends SceneTree
## Headless test: the camera rig is isometric orthographic from the first frame (configured by its
## CameraViewConfig profile), follows the player, rotates (Q / E, right drag) and zooms (wheel, PgUp / PgDn) within
## its limits with movement staying screen-relative (task-051), and swaps to a tilted view without touching the world scene.
## Usage: godot --headless --path . -s tools/test_camera_rig.gd


const Support := preload("res://tools/test_support.gd")


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	Support.isolate_save(main, "camera_rig")
	var intro_cfg := IntroConfig.new()
	intro_cfg.black_hold = 0.05
	intro_cfg.wave_fade_in = 0.05
	intro_cfg.wave_hold = 0.05
	intro_cfg.reveal_duration = 0.05
	main.get_node("IntroSequence").set("config", intro_cfg)
	root.add_child(main)
	await process_frame
	var rig: Node3D = main.get_node("CameraRig")
	var cam: Camera3D = rig.get_node("Camera3D")
	var ok := true

	# Isometric from the very first frame: orthographic, looking down-and-toward -x,-z at the profile's angles.
	var iso: CameraViewConfig = load("res://resources/config/camera_isometric.tres")
	var expected: Vector3 = Basis.from_euler(Vector3(deg_to_rad(iso.pitch_degrees), deg_to_rad(iso.yaw_degrees), 0.0)) * Vector3.FORWARD
	var look := cam.global_transform.basis * Vector3.FORWARD
	ok = ok and cam.projection == Camera3D.PROJECTION_ORTHOGONAL
	ok = ok and is_equal_approx(cam.size, iso.size)
	ok = ok and look.is_equal_approx(expected)
	ok = ok and look.y < 0.0 and look.x < 0.0 and look.z < 0.0
	ok = ok and absf(look.x - look.z) < 0.0001
	ok = ok and is_equal_approx(cam.near, iso.near) and is_equal_approx(cam.far, iso.far)
	print("iso look dir: ", look, " expected: ", expected)

	# It follows the player on the XZ plane and looks at a point look_height above the floor.
	# Let the (shortened) intro hand off first: the run start re-places the player at the spawn.
	await create_timer(0.6).timeout
	var player: Node3D = main.get_node("Player")
	player.global_position = Vector3(7.0, 0.0, 9.0)
	for i in 30:
		await process_frame
	ok = ok and absf(rig.global_position.x - 7.0) < 0.05 and absf(rig.global_position.z - 9.0) < 0.05
	ok = ok and is_equal_approx(rig.global_position.y, iso.look_height)
	print("rig follows player: ", rig.global_position)

	ok = await _check_controls(main, rig, cam, iso) and ok

	var world_before := main.get_node("World").get_child_count()
	rig.call("apply_view", load("res://resources/config/camera_tilted.tres"))
	var tilted := cam.global_transform.basis * Vector3.FORWARD
	print("tilted look dir: ", tilted, " projection: ", cam.projection)
	ok = ok and cam.projection == Camera3D.PROJECTION_PERSPECTIVE
	ok = ok and not tilted.is_equal_approx(Vector3.DOWN) and tilted.y < 0.0
	ok = ok and main.get_node("World").get_child_count() == world_before

	Support.remove_file("user://test_progress_camera_rig.tres")
	print("PASS test_camera_rig" if ok else "FAIL test_camera_rig")
	quit(0 if ok else 1)


func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _mouse(button: MouseButton, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = Vector2(200, 200)
	e.global_position = e.position
	Input.parse_input_event(e)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _yaw(rig: Node3D) -> float:
	return float(rig.call("current_yaw_degrees"))


## Look direction projected on the ground, as an angle (degrees) — what the player sees as "up".
func _ground_heading(cam: Camera3D) -> float:
	var f: Vector3 = cam.global_basis * Vector3.FORWARD
	return rad_to_deg(atan2(-f.x, -f.z))


func _check_controls(main: Node, rig: Node3D, cam: Camera3D, iso: CameraViewConfig) -> bool:
	var ok := true
	var runs: Node = main.get_node("RunManager")
	ok = ok and runs.get("phase") == 1
	print("run playing: ", runs.get("phase") == 1)

	# Q held swings the camera to its left (yaw down), E back; the camera transform follows.
	var yaw0: float = _yaw(rig)
	var heading0: float = _ground_heading(cam)
	_key(KEY_Q, true)
	await _wait(0.5)
	_key(KEY_Q, false)
	await _wait(1.0)
	var yaw_q: float = _yaw(rig)
	var turned: float = yaw0 - yaw_q
	var heading_turn: float = wrapf(heading0 - _ground_heading(cam), -180.0, 180.0)
	print("Q turned yaw by ", turned, " heading by ", heading_turn)
	ok = ok and turned > iso.rotate_speed_degrees * 0.3 and turned < iso.rotate_speed_degrees * 0.8
	ok = ok and absf(heading_turn - turned) < 0.5
	_key(KEY_E, true)
	await _wait(0.25)
	_key(KEY_E, false)
	await _wait(0.6)
	print("E turned yaw back by ", _yaw(rig) - yaw_q)
	ok = ok and _yaw(rig) > yaw_q + 1.0

	# Right drag rotates by drag_degrees_per_pixel; without the button, motion does nothing.
	var before_drag: float = _yaw(rig)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100.0, 0.0)
	Input.parse_input_event(motion)
	await _wait(0.3)
	ok = ok and is_equal_approx(_yaw(rig), before_drag)
	_mouse(MOUSE_BUTTON_RIGHT, true)
	Input.parse_input_event(motion.duplicate())
	_mouse(MOUSE_BUTTON_RIGHT, false)
	await _wait(1.0)
	var dragged: float = _yaw(rig) - before_drag
	print("right drag 100px turned yaw by ", dragged)
	ok = ok and absf(dragged + 100.0 * iso.drag_degrees_per_pixel) < 0.1
	ok = ok and not main.get_node("MenuController").call("is_open")

	# Wheel up zooms in (smaller ortho size), clamped at zoom_min; PgDn zooms out, clamped at zoom_max.
	var size0: float = cam.size
	_mouse(MOUSE_BUTTON_WHEEL_UP, true)
	_mouse(MOUSE_BUTTON_WHEEL_UP, false)
	await _wait(0.6)
	print("wheel up: size ", size0, " -> ", cam.size)
	ok = ok and cam.size < size0 * 0.95
	for i in 30:
		_mouse(MOUSE_BUTTON_WHEEL_UP, true)
	await _wait(1.0)
	print("zoomed in fully: ", cam.size, " (min ", iso.size * iso.zoom_min, ")")
	ok = ok and absf(cam.size - iso.size * iso.zoom_min) < 0.01
	for i in 40:
		_key(KEY_PAGEDOWN, true)
		_key(KEY_PAGEDOWN, false)
	await _wait(1.0)
	print("zoomed out fully: ", cam.size, " (max ", iso.size * iso.zoom_max, ")")
	ok = ok and absf(cam.size - iso.size * iso.zoom_max) < 0.01
	_key(KEY_PAGEUP, true)
	_key(KEY_PAGEUP, false)
	await _wait(0.6)
	ok = ok and cam.size < iso.size * iso.zoom_max - 0.1

	# Movement stays screen-relative after rotating: D moves right on screen, W up.
	var player: CharacterBody3D = main.get_node("Player")
	var spawn: Vector3 = (main.get_node("World/MapLoader") as MapLoader).spawn_position
	for step: Array in [[KEY_D, Vector2.RIGHT], [KEY_W, Vector2.UP]]:
		player.global_position = spawn
		player.velocity = Vector3.ZERO
		await _wait(0.1)
		var from: Vector3 = player.global_position
		_key(step[0], true)
		await _wait(0.3)
		_key(step[0], false)
		var d3: Vector3 = player.global_position - from
		var screen := Vector2(d3.dot(cam.global_basis.x), -d3.dot(cam.global_basis.y))
		var want: Vector2 = step[1]
		var along: float = screen.dot(want)
		var off: float = absf(screen.dot(Vector2(-want.y, want.x)))
		print("rotated view, key ", OS.get_keycode_string(step[0]), " screen delta ", screen)
		ok = ok and along > 0.3 and off <= 0.1 * along
		await _wait(0.4)

	# The pointer still walks toward the clicked ground point (it projects through the rotated camera).
	player.global_position = spawn
	player.velocity = Vector3.ZERO
	await _wait(0.2)
	var target: Vector3 = spawn + Vector3(-2.0, 0.0, 0.0)
	var cursor: Vector2 = cam.unproject_position(target)
	var move := InputEventMouseMotion.new()
	move.position = cursor
	move.global_position = cursor
	Input.parse_input_event(move)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = cursor
	press.global_position = cursor
	Input.parse_input_event(press)
	await _wait(0.4)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	var walked: Vector3 = player.global_position - spawn
	print("pointer walk after rotation: ", walked)
	ok = ok and walked.x < -0.5 and absf(walked.z) < 0.2 * absf(walked.x)
	await _wait(0.5)
	return ok
