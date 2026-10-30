extends SceneTree
## Rebuilds res://main.tscn: map loader, player, locked camera rig, overlays, run manager.
## Run tools/build_resources.gd first. Idempotent.
## Usage: godot --headless --path . -s tools/build_main_scene.gd

const SCENE_PATH := "res://main.tscn"
const CFG := "res://resources/config/"
const MAP_PATH := "res://data/maps/m1_awakening.txt"
const OVERLAY_LAYER := 10
const INTRO_LAYER := 20


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

	var loader: MapLoader = MapLoader.new()
	loader.name = "MapLoader"
	loader.legend = load(CFG + "map_legend.tres") as MapLegend
	loader.world_config = load(CFG + "world_config.tres") as WorldConfig
	loader.map_path = MAP_PATH
	_add(world, loader)

	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-60.0, 30.0, 0.0)
	_add(world, light)

	var save: Node = load("res://scripts/core/save_service.gd").new()
	save.name = "SaveService"
	_add(root, save)

	var rig: Node3D = load("res://scripts/rendering/camera_rig.gd").new()
	rig.name = "CameraRig"
	rig.set("view_config", load(CFG + "camera_top_down.tres"))
	_add(root, rig)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	_add(rig, cam)

	var player_cfg: PlayerConfig = load(CFG + "player_config.tres")
	var player: CharacterBody3D = load("res://scripts/player/player.gd").new()
	player.name = "Player"
	player.set("config", player_cfg)
	player.set("map_loader", loader)
	player.set("save_service", save)
	var body := CollisionShape3D.new()
	body.name = "Collision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = player_cfg.body_radius
	capsule.height = player_cfg.body_height
	body.shape = capsule
	body.position.y = player_cfg.body_height * 0.5
	player.add_child(body)
	_add(root, player)
	rig.set("follow_target", player)

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

	# Layer 10 overlay: crisp glyphs the ASCII shader must not touch (decision-001).
	var overlay: CanvasLayer = load("res://scripts/rendering/glyph_overlay.gd").new()
	overlay.name = "GlyphOverlay"
	overlay.layer = OVERLAY_LAYER
	overlay.set("camera_rig", rig)
	overlay.set("player", player)
	overlay.set("player_config", player_cfg)
	_add(root, overlay)

	# Layer 20: intro veil + wave, above everything.
	var intro: CanvasLayer = load("res://scripts/ui/intro_sequence.gd").new()
	intro.name = "IntroSequence"
	intro.layer = INTRO_LAYER
	intro.set("config", load(CFG + "intro_config.tres"))
	_add(root, intro)
	var veil := ColorRect.new()
	veil.name = "Veil"
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var veil_mat := ShaderMaterial.new()
	veil_mat.shader = load("res://shaders/intro_wave.gdshader")
	veil.material = veil_mat
	_add(intro, veil)

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


## Adds child and sets owner (recursively) to the scene root so it is packed.
func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)
	var owner_node: Node = parent if parent.owner == null and parent.get_parent() == null else parent.owner
	_own(child, owner_node)


func _own(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for c in node.get_children():
		_own(c, owner_node)
