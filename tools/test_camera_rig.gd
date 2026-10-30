extends SceneTree
## Headless test: the camera rig is isometric orthographic from the first frame (configured by its
## CameraViewConfig profile), follows the player, and swaps to a tilted view without touching the world scene.
## Usage: godot --headless --path . -s tools/test_camera_rig.gd


const Support := preload("res://tools/test_support.gd")


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	Support.isolate_save(main, "camera_rig")
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
	var player: Node3D = main.get_node("Player")
	player.global_position = Vector3(7.0, 0.0, 9.0)
	for i in 30:
		await process_frame
	ok = ok and absf(rig.global_position.x - 7.0) < 0.05 and absf(rig.global_position.z - 9.0) < 0.05
	ok = ok and is_equal_approx(rig.global_position.y, iso.look_height)
	print("rig follows player: ", rig.global_position)

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
