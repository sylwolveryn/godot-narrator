extends SceneTree
## Rebuilds res://main.tscn: map loader (glyph-surface world), player, isometric camera rig, glyph world
## view, player glyph and halos, narration overlay, run manager. Run tools/build_resources.gd and tools/build_glyph_material.gd first. Idempotent.
## Usage: godot --headless --path . -s tools/build_main_scene.gd

const SCENE_PATH := "res://main.tscn"
const CFG := "res://resources/config/"
const DISPLAY_CONFIG := "res://resources/config/display_config.tres"
const GLYPH_MATERIAL := "res://resources/glyphs/glyph_surface_material.tres"
const NARRATION_DIR := "res://resources/narration/"
const MAP_PATH := "res://data/maps/m1_awakening.txt"
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
	loader.surface_material = load(GLYPH_MATERIAL) as Material
	loader.map_path = MAP_PATH
	_add(world, loader)

	var save: Node = load("res://scripts/core/save_service.gd").new()
	save.name = "SaveService"
	save.set("config", load(CFG + "save_config.tres"))
	_add(root, save)

	# Origin ledger (task-039): the only writer of the rule-out state; right after SaveService so it repairs the loaded
	# save before anything reads it. Run tools/build_origin.gd first.
	var ledger: Node = load("res://scripts/origin/origin_ledger.gd").new()
	ledger.name = "OriginLedger"
	ledger.set("config", load(CFG + "origin_config.tres"))
	ledger.set("save_service", save)
	_add(root, ledger)

	# Narrator sits right after SaveService and before Player/MapReveal: signal handlers run in tree
	# order, so counters are updated and run_started is seen before the first reveal events.
	# Entity growth (task-017): unlocks and owns the active form; sits right after SaveService so its unlock
	# check follows the death count update.
	var entity_cfg: EntityGrowthConfig = load(CFG + "entity_growth_config.tres")
	var progression: Node = load("res://scripts/core/entity_progression.gd").new()
	progression.name = "EntityProgression"
	progression.set("config", entity_cfg)
	progression.set("save_service", save)
	_add(root, progression)

	# In-world menu (task-018): logic node right after EntityProgression (reads the form it switches). The run manager
	# is wired after it exists (see below).
	var menu_cfg: MenuConfig = load(CFG + "menu_config.tres")
	var menu: Node = load("res://scripts/core/menu_controller.gd").new()
	menu.name = "MenuController"
	menu.set("config", menu_cfg)
	menu.set("save_service", save)
	menu.set("entity", progression)
	menu.set("ledger", ledger)
	_add(root, menu)

	var narrator_cfg: NarratorConfig = load(NARRATION_DIR + "narrator_config.tres")
	var narrator: Node = load("res://scripts/narrator/narrator.gd").new()
	narrator.name = "Narrator"
	narrator.set("config", narrator_cfg)
	narrator.set("save_service", save)
	narrator.set("ledger", ledger)
	_add(root, narrator)

	var rig: Node3D = load("res://scripts/rendering/camera_rig.gd").new()
	rig.name = "CameraRig"
	rig.set("view_config", load(CFG + "camera_isometric.tres"))
	_add(root, rig)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.01, 0.018)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	cam.environment = env
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
	player.set("camera_rig", rig)

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

	# The glyph-surface world feeds its material (lights, cut-away). No full-screen post-process.
	var glyph_view: Node = load("res://scripts/rendering/glyph_world_view.gd").new()
	glyph_view.name = "GlyphWorldView"
	glyph_view.set("config", load(CFG + "glyph_world_config.tres"))
	glyph_view.set("map_loader", loader)
	glyph_view.set("player", player)
	glyph_view.set("map_reveal", reveal)
	_add(root, glyph_view)

	# The player's glyph stands in the world: one MultiMesh of billboards (glyph + halo + fragments).
	var player_glyph: Node3D = load("res://scripts/rendering/player_glyph_view.gd").new()
	player_glyph.name = "PlayerGlyphView"
	player_glyph.set("player", player)
	player_glyph.set("player_config", player_cfg)
	player_glyph.set("fx_config", load(CFG + "glyph_fx_config.tres"))
	player_glyph.set("world_config", load(CFG + "glyph_world_config.tres"))
	player_glyph.set("world", load(CFG + "world_config.tres"))
	player_glyph.set("entity_config", entity_cfg)
	_add(root, player_glyph)

	# The in-world menu: glyphs of the surroundings fly into a framed list (one MultiMesh, hidden while closed).
	var menu_view: Node3D = load("res://scripts/rendering/menu_glyph_view.gd").new()
	menu_view.name = "MenuGlyphView"
	menu_view.set("config", menu_cfg)
	menu_view.set("fx_config", load(CFG + "glyph_fx_config.tres"))
	menu_view.set("player", player)
	menu_view.set("player_config", player_cfg)
	menu_view.set("map_loader", loader)
	menu_view.set("world", load(CFG + "world_config.tres"))
	menu_view.set("origin_config", load(CFG + "origin_config.tres"))
	menu_view.set("surface_material", load(GLYPH_MATERIAL))
	_add(root, menu_view)

	# Soft halos over items, spikes and corruption: one MultiMesh, reveal-aware in the shader.
	var halos: Node3D = load("res://scripts/rendering/glyph_halo_field.gd").new()
	halos.name = "GlyphHaloField"
	halos.set("config", load(CFG + "glyph_world_config.tres"))
	halos.set("map_loader", loader)
	_add(root, halos)

	# Narration text: above the world and above the intro veil (decision-001).
	var narration: CanvasLayer = load("res://scripts/narrator/narration_overlay.gd").new()
	narration.name = "NarrationOverlay"
	narration.layer = narrator_cfg.overlay_layer
	narration.set("narrator", narrator)
	narration.set("config", narrator_cfg)
	narration.set("display_config", load(DISPLAY_CONFIG))
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
	menu.set("run_manager", runs)

	# Small pushable objects (task-019): data layer (cells, collision, pushing) and its MultiMesh presentation.
	var push_cfg: PushConfig = load(CFG + "push_config.tres")
	var pushables: Node3D = load("res://scripts/world/pushable_objects.gd").new()
	pushables.name = "PushableObjects"
	pushables.set("config", push_cfg)
	pushables.set("map_loader", loader)
	pushables.set("player", player)
	pushables.set("entity", progression)
	pushables.set("run_manager", runs)
	_add(root, pushables)
	var object_view: Node3D = load("res://scripts/rendering/object_glyph_view.gd").new()
	object_view.name = "ObjectGlyphView"
	object_view.set("pushables", pushables)
	object_view.set("map_loader", loader)
	object_view.set("config", push_cfg)
	_add(root, object_view)

	var hazards: Node = load("res://scripts/world/hazard_monitor.gd").new()
	hazards.name = "HazardMonitor"
	hazards.set("map_loader", loader)
	hazards.set("player", player)
	hazards.set("run_manager", runs)
	_add(root, hazards)

	# Origin trial monitor (task-041): evaluates the demonic / ai / angelic trials from existing signals.
	var trials: Node = load("res://scripts/origin/origin_trial_monitor.gd").new()
	trials.name = "OriginTrialMonitor"
	trials.set("ledger", ledger)
	trials.set("run_manager", runs)
	trials.set("player", player)
	trials.set("map_loader", loader)
	_add(root, trials)

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
