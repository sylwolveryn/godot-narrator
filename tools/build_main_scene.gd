extends SceneTree
## Rebuilds res://main.tscn: map loader, player, locked camera rig, overlays, run manager.
## Run tools/build_resources.gd first. Idempotent.
## Usage: godot --headless --path . -s tools/build_main_scene.gd

const SCENE_PATH := "res://main.tscn"
const CFG := "res://resources/config/"
const DISPLAY_CONFIG := "res://resources/config/display_config.tres"
const NARRATION_DIR := "res://resources/narration/"
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
	loader.hazard_fx = load(CFG + "hazard_fx_config.tres") as HazardFxConfig
	loader.map_path = MAP_PATH
	_add(world, loader)

	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-60.0, 30.0, 0.0)
	_add(world, light)

	var save: Node = load("res://scripts/core/save_service.gd").new()
	save.name = "SaveService"
	save.set("config", load(CFG + "save_config.tres"))
	_add(root, save)

	# Narrator sits right after SaveService and before Player/MapReveal: signal handlers run in tree
	# order, so counters are updated and run_started is seen before the first reveal events.
	var narrator_cfg: NarratorConfig = load(NARRATION_DIR + "narrator_config.tres")
	var narrator: Node = load("res://scripts/narrator/narrator.gd").new()
	narrator.name = "Narrator"
	narrator.set("config", narrator_cfg)
	narrator.set("save_service", save)
	_add(root, narrator)

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

	# Reveal comes after the player so run-start handlers run in spawn-then-reveal order.
	var reveal: Node = load("res://scripts/world/map_reveal.gd").new()
	reveal.name = "MapReveal"
	reveal.set("config", load(CFG + "reveal_config.tres"))
	reveal.set("map_loader", loader)
	reveal.set("player", player)
	reveal.set("save_service", save)
	_add(root, reveal)

	var discovery: Node = load("res://scripts/player/input_discovery.gd").new()
	discovery.name = "InputDiscovery"
	discovery.set("config", player_cfg)
	_add(root, discovery)

	# Layer 0 post-process: reads the data-encoded 3D render and replaces it with glyphs.
	var ascii: CanvasLayer = load("res://scripts/rendering/ascii_post_process.gd").new()
	ascii.name = "AsciiPostProcess"
	ascii.layer = 0
	ascii.set("config", load(CFG + "ascii_config.tres"))
	ascii.set("display_config", load(DISPLAY_CONFIG))
	ascii.set("palette", load(CFG + "palette_config.tres"))
	ascii.set("light_config", load(CFG + "light_config.tres"))
	ascii.set("hazard_fx", load(CFG + "hazard_fx_config.tres"))
	ascii.set("glyph_fx", load(CFG + "glyph_fx_config.tres"))
	ascii.set("camera_rig", rig)
	ascii.set("player", player)
	ascii.set("identity_pool", player_cfg.identity_pool)
	ascii.set("narrator_config", narrator_cfg)
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
	overlay.set("fx_config", load(CFG + "glyph_fx_config.tres"))
	overlay.set("display_config", load(DISPLAY_CONFIG))
	overlay.set("world_config", loader.world_config)
	overlay.set("ascii", ascii)
	_add(root, overlay)

	# Narration text: above the ASCII shader and above the intro veil (decision-001).
	var narration: CanvasLayer = load("res://scripts/narrator/narration_overlay.gd").new()
	narration.name = "NarrationOverlay"
	narration.layer = narrator_cfg.overlay_layer
	narration.set("narrator", narrator)
	narration.set("config", narrator_cfg)
	narration.set("display_config", load(DISPLAY_CONFIG))
	narration.set("ascii", ascii)
	_add(root, narration)

	var sfx: Node = load("res://scripts/narrator/narration_sfx.gd").new()
	sfx.name = "NarrationSfx"
	sfx.set("narrator", narrator)
	sfx.set("config", narrator_cfg)
	_add(root, sfx)

	# Layer 20: intro veil + wave, above everything.
	var intro: CanvasLayer = load("res://scripts/ui/intro_sequence.gd").new()
	intro.name = "IntroSequence"
	intro.layer = INTRO_LAYER
	intro.set("config", load(CFG + "intro_config.tres"))
	intro.set("display_config", load(DISPLAY_CONFIG))
	_add(root, intro)
	var veil := ColorRect.new()
	veil.name = "Veil"
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var veil_mat := ShaderMaterial.new()
	veil_mat.shader = load("res://shaders/intro_wave.gdshader")
	veil.material = veil_mat
	_add(intro, veil)

	var fullscreen: Node = load("res://scripts/ui/fullscreen_toggle.gd").new()
	fullscreen.name = "FullscreenToggle"
	fullscreen.set("config", load(DISPLAY_CONFIG))
	_add(root, fullscreen)

	var runs: Node = load("res://scripts/core/run_manager.gd").new()
	runs.name = "RunManager"
	runs.set("config", load(CFG + "run_config.tres"))
	_add(root, runs)
	player.set("run_manager", runs)

	var hazards: Node = load("res://scripts/world/hazard_monitor.gd").new()
	hazards.name = "HazardMonitor"
	hazards.set("map_loader", loader)
	hazards.set("player", player)
	hazards.set("run_manager", runs)
	_add(root, hazards)

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
