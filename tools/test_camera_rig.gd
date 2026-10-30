extends SceneTree
## Headless test: camera rig is configured by profile and swaps to a tilted view
## without touching the world scene.
## Usage: godot --headless --path . -s tools/test_camera_rig.gd


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var rig: Node3D = main.get_node("CameraRig")
	var cam: Camera3D = rig.get_node("Camera3D")
	var ok := true

	var down := cam.global_transform.basis * Vector3.FORWARD
	ok = ok and cam.projection == Camera3D.PROJECTION_ORTHOGONAL
	ok = ok and down.is_equal_approx(Vector3.DOWN)
	print("top-down look dir: ", down)

	var world_before := main.get_node("World").get_child_count()
	rig.call("apply_view", load("res://resources/config/camera_tilted.tres"))
	var tilted := cam.global_transform.basis * Vector3.FORWARD
	print("tilted look dir: ", tilted, " projection: ", cam.projection)
	ok = ok and cam.projection == Camera3D.PROJECTION_PERSPECTIVE
	ok = ok and not tilted.is_equal_approx(Vector3.DOWN) and tilted.y < 0.0
	ok = ok and main.get_node("World").get_child_count() == world_before

	print("PASS test_camera_rig" if ok else "FAIL test_camera_rig")
	quit(0 if ok else 1)
