extends SceneTree
## Rebuilds res://main.tscn: world placeholder geometry, locked camera rig, run manager.
## Run tools/build_resources.gd first. Idempotent.
## Usage: godot --headless --path . -s tools/build_main_scene.gd

const SCENE_PATH := "res://main.tscn"
const CFG := "res://resources/config/"
const FLOOR_SIZE := Vector2(20.0, 20.0)
const WALL_SIZE := Vector3(20.0, 1.0, 1.0)


func _init() -> void:
	# Autoloads (SignalBus) are only registered after _init, and the game scripts
	# reference them, so build on the first frame instead.
	process_frame.connect(_build, CONNECT_ONE_SHOT)


func _build() -> void:
	var root := Node3D.new()
	root.name = "Main"

	var world := Node3D.new()
	world.name = "World"
	_add(root, world)

	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	var plane := PlaneMesh.new()
	plane.size = FLOOR_SIZE
	floor_mesh.mesh = plane
	_add(world, floor_mesh)

	for wall_def: Array in [["WallNorth", Vector3(0, 0.5, -10)], ["WallSouth", Vector3(0, 0.5, 10)]]:
		_add(world, _make_wall(wall_def[0], wall_def[1]))

	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-60.0, 30.0, 0.0)
	_add(world, light)

	var rig: Node3D = load("res://scripts/rendering/camera_rig.gd").new()
	rig.name = "CameraRig"
	rig.set("view_config", load(CFG + "camera_top_down.tres"))
	_add(root, rig)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	_add(rig, cam)

	# Layer 0 post-process: reads the 3D render and replaces it with glyphs.
	var ascii: CanvasLayer = load("res://scripts/rendering/ascii_post_process.gd").new()
	ascii.name = "AsciiPostProcess"
	ascii.layer = 0
	ascii.set("config", load(CFG + "ascii_config.tres"))
	_add(root, ascii)
	var screen := ColorRect.new()
	screen.name = "Screen"
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ascii_post.gdshader")
	screen.material = mat
	_add(ascii, screen)

	var runs: Node = load("res://scripts/core/run_manager.gd").new()
	runs.name = "RunManager"
	runs.set("config", load(CFG + "run_config.tres"))
	_add(root, runs)

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	root.free()
	if pack_err != OK:
		push_error("Failed to pack Main scene: %s" % error_string(pack_err))
		quit(1)
		return

	# project.godot points at the main scene by UID, so keep the existing one.
	var uid := ResourceLoader.get_resource_uid(SCENE_PATH)

	var save_err := ResourceSaver.save(packed, SCENE_PATH)
	if save_err != OK:
		push_error("Failed to save %s: %s" % [SCENE_PATH, error_string(save_err)])
		quit(1)
		return

	if uid != ResourceUID.INVALID_ID:
		var uid_err := ResourceSaver.set_uid(SCENE_PATH, uid)
		if uid_err != OK:
			push_error("Failed to set uid on %s: %s" % [SCENE_PATH, error_string(uid_err)])
			quit(1)
			return

	print("Saved %s (uid %s)" % [SCENE_PATH, ResourceUID.id_to_text(ResourceLoader.get_resource_uid(SCENE_PATH))])
	quit()


func _make_wall(wall_name: String, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = wall_name
	body.position = pos
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = WALL_SIZE
	mesh.mesh = box
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var bs := BoxShape3D.new()
	bs.size = WALL_SIZE
	shape.shape = bs
	body.add_child(shape)
	return body


## Adds child and sets owner (recursively) to the scene root so it is packed.
func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)
	var owner_node: Node = parent if parent.owner == null and parent.get_parent() == null else parent.owner
	_own(child, owner_node)


func _own(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for c in node.get_children():
		_own(c, owner_node)
