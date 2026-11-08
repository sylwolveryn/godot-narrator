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

	# Data layer (task-048): the SpacetimeDB link first, so every reader can connect to it in _ready.
	var database: Node = load("res://scripts/data/game_database.gd").new()
	database.name = "GameDatabase"
	database.set("config", load(CFG + "db_config.tres"))
	_add(root, database)
	var library_cfg: NarrationLibraryConfig = load(CFG + "narration_library_config.tres")
	var library: Node = load("res://scripts/narrator/narration_library.gd").new()
	library.name = "NarrationLibrary"
	library.set("config", library_cfg)
	library.set("database", database)
	_add(root, library)
	# Per-map visibility rules (task-069): picks the map_settings row of the loaded map; MapReveal and GlyphWorldView read it.
	var map_settings: Node = load("res://scripts/data/map_settings_resolver.gd").new()
	map_settings.name = "MapSettingsResolver"
	map_settings.set("database", database)
	map_settings.set("map_loader", loader)
	_add(root, map_settings)
	var record: Node = load("res://scripts/core/player_record.gd").new()
	record.name = "PlayerRecord"
	record.set("database", database)
	_add(root, record)

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

	# Language understanding (task-065): the only writer of the language progress; after SaveService (repairs the loaded
	# save) and before Narrator / MenuController so its run-start announcement comes first. The player is wired below.
	var language: Node = load("res://scripts/core/language_progress.gd").new()
	language.name = "LanguageProgress"
	language.set("config", load(CFG + "language_config.tres"))
	language.set("save_service", save)
	language.set("map_loader", loader)
	language.set("database", database)
	_add(root, language)

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
	menu.set("language", language)
	_add(root, menu)

	var narrator_cfg: NarratorConfig = load(NARRATION_DIR + "narrator_config.tres")
	var narrator: Node = load("res://scripts/narrator/narrator.gd").new()
	narrator.name = "Narrator"
	narrator.set("config", narrator_cfg)
	narrator.set("save_service", save)
	narrator.set("ledger", ledger)
	narrator.set("library", library)
	_add(root, narrator)

	# Dirt walls (task-070): the only writer of the dirt state (the one destroy entry point, chunked collision, the eaten
	# counter). Before Player and MapReveal so destroyed cells are dirt again before the run-start spawn reveals.
	# Destructibles (task-073): the registry the owners of destructible things opt into (dirt, large props, teleports,
	# later enemies); cannon balls query it by cell.
	var destructibles: Node = load("res://scripts/world/destructibles.gd").new()
	destructibles.name = "Destructibles"
	_add(root, destructibles)
	var dirt_cfg: DirtConfig = load(CFG + "dirt_config.tres")
	var dirt: Node3D = load("res://scripts/world/dirt_walls.gd").new()
	dirt.name = "DirtWalls"
	dirt.set("config", dirt_cfg)
	dirt.set("map_loader", loader)
	dirt.set("save_service", save)
	dirt.set("destructibles", destructibles)
	_add(root, dirt)
	# The only writer of the destroyed state of merged props (task-073); restores them at run start like the dirt.
	var large_objects: Node = load("res://scripts/world/large_objects.gd").new()
	large_objects.name = "LargeObjects"
	large_objects.set("map_loader", loader)
	large_objects.set("destructibles", destructibles)
	_add(root, large_objects)

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
	player.set("database", database)
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
	language.set("player", player)
	player.set("camera_rig", rig)

	# Reveal comes after the player so run-start handlers run in spawn-then-reveal order.
	var reveal: Node = load("res://scripts/world/map_reveal.gd").new()
	reveal.name = "MapReveal"
	reveal.set("config", load(CFG + "reveal_config.tres"))
	reveal.set("map_loader", loader)
	reveal.set("player", player)
	reveal.set("save_service", save)
	reveal.set("settings", map_settings)
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
	glyph_view.set("settings", map_settings)
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
	player_glyph.set("avatar_config", load(CFG + "avatar_fx_config.tres"))
	player_glyph.set("database", database)
	player_glyph.set("teleport_config", load(CFG + "teleport_config.tres"))
	_add(root, player_glyph)

	# Ink trail behind the moving player (task-057): one MultiMesh of fading ink glyphs; values from DB avatar_fx.
	var ink: Node3D = load("res://scripts/rendering/ink_trail_view.gd").new()
	ink.name = "InkTrailView"
	ink.set("config", load(CFG + "avatar_fx_config.tres"))
	ink.set("database", database)
	ink.set("player", player)
	_add(root, ink)

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

	# The glyph storm (task-030): glyphs of the surroundings swirl around the player; one MultiMesh, no per-instance data.
	# Run tools/build_storm.gd first.
	var storm_view: Node3D = load("res://scripts/rendering/glyph_storm_view.gd").new()
	storm_view.name = "GlyphStormView"
	storm_view.set("config", load(CFG + "storm_config.tres"))
	storm_view.set("fx_config", load(CFG + "glyph_fx_config.tres"))
	storm_view.set("player", player)
	storm_view.set("map_loader", loader)
	storm_view.set("world", load(CFG + "world_config.tres"))
	storm_view.set("surface_material", load(GLYPH_MATERIAL))
	_add(root, storm_view)

	# DB-driven glyph animation (task-054): cycling characters and palettes per surface, from the glyph_anim table.
	var anim_view: Node = load("res://scripts/rendering/glyph_anim_view.gd").new()
	anim_view.name = "GlyphAnimView"
	anim_view.set("config", load(CFG + "glyph_anim_config.tres"))
	anim_view.set("database", database)
	anim_view.set("map_loader", loader)
	_add(root, anim_view)

	# Soft halos over items, spikes and corruption: one MultiMesh, reveal-aware in the shader.
	var halos: Node3D = load("res://scripts/rendering/glyph_halo_field.gd").new()
	halos.name = "GlyphHaloField"
	halos.set("config", load(CFG + "glyph_world_config.tres"))
	halos.set("map_loader", loader)
	_add(root, halos)

	# Merged multi-cell props (task-058): ASCII-art Label3D pieces scaled to their footprint, reveal-aware.
	var large_view: Node3D = load("res://scripts/rendering/large_object_view.gd").new()
	large_view.name = "LargeObjectView"
	large_view.set("map_loader", loader)
	large_view.set("map_reveal", reveal)
	_add(root, large_view)

	# Narration text: above the world and above the intro veil (decision-001).
	var narration: CanvasLayer = load("res://scripts/narrator/narration_overlay.gd").new()
	narration.name = "NarrationOverlay"
	narration.layer = narrator_cfg.overlay_layer
	narration.set("narrator", narrator)
	narration.set("config", narrator_cfg)
	narration.set("display_config", load(DISPLAY_CONFIG))
	narration.set("player_config", player_cfg)
	_add(root, narration)

	var sfx: Node = load("res://scripts/narrator/narration_sfx.gd").new()
	sfx.name = "NarrationSfx"
	sfx.set("narrator", narrator)
	sfx.set("config", narrator_cfg)
	sfx.set("voice_volume_db", library_cfg.voice_volume_db)
	_add(root, sfx)

	# Interact (task-072) and cannons (task-073). Interactables must sit after MenuController / InputDiscovery and before
	# IntroSequence: its _input sees the press before the menu and the discovery, after the intro's skip capture.
	var interact_cfg: InteractConfig = load(CFG + "interact_config.tres")
	var interactables: Node = load("res://scripts/world/interactables.gd").new()
	interactables.name = "Interactables"
	interactables.set("config", interact_cfg)
	interactables.set("map_loader", loader)
	interactables.set("player", player)
	_add(root, interactables)
	var cannon_cfg: CannonConfig = load(CFG + "cannon_config.tres")
	var balls: Node = load("res://scripts/world/cannon_balls.gd").new()
	balls.name = "CannonBalls"
	balls.set("config", cannon_cfg)
	balls.set("map_loader", loader)
	balls.set("destructibles", destructibles)
	balls.set("player", player)
	balls.set("player_config", player_cfg)
	_add(root, balls)
	var cannons: Node = load("res://scripts/world/cannon_system.gd").new()
	cannons.name = "CannonSystem"
	cannons.set("config", cannon_cfg)
	cannons.set("map_loader", loader)
	cannons.set("player", player)
	cannons.set("interactables", interactables)
	cannons.set("balls", balls)
	_add(root, cannons)
	var cannon_view: Node3D = load("res://scripts/rendering/cannon_view.gd").new()
	cannon_view.name = "CannonView"
	cannon_view.set("config", cannon_cfg)
	cannon_view.set("cannons", cannons)
	cannon_view.set("map_loader", loader)
	cannon_view.set("map_reveal", reveal)
	cannon_view.set("camera_rig", rig)
	_add(root, cannon_view)
	var ball_view: Node3D = load("res://scripts/rendering/cannon_ball_view.gd").new()
	ball_view.name = "CannonBallView"
	ball_view.set("config", cannon_cfg)
	ball_view.set("balls", balls)
	_add(root, ball_view)
	var hint: Node3D = load("res://scripts/rendering/interact_hint_view.gd").new()
	hint.name = "InteractHintView"
	hint.set("config", interact_cfg)
	hint.set("player", player)
	_add(root, hint)
	var boom: Node = load("res://scripts/world/cannon_boom_sfx.gd").new()
	boom.name = "CannonBoomSfx"
	boom.set("config", cannon_cfg)
	boom.set("library", library)
	_add(root, boom)

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
	interactables.set("run_manager", runs)
	ink.set("run_manager", runs)

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
	balls.set("pushables", pushables)
	var object_view: Node3D = load("res://scripts/rendering/object_glyph_view.gd").new()
	object_view.name = "ObjectGlyphView"
	object_view.set("pushables", pushables)
	object_view.set("map_loader", loader)
	object_view.set("config", push_cfg)
	_add(root, object_view)
	# Dirt presentation (task-070): chunk meshes, crumble and dust, and the crunch.
	var dirt_view: Node3D = load("res://scripts/rendering/dirt_view.gd").new()
	dirt_view.name = "DirtView"
	dirt_view.set("config", dirt_cfg)
	dirt_view.set("map_loader", loader)
	dirt_view.set("dirt_walls", dirt)
	_add(root, dirt_view)
	var crunch: Node = load("res://scripts/world/dirt_crunch_sfx.gd").new()
	crunch.name = "DirtCrunchSfx"
	crunch.set("config", dirt_cfg)
	crunch.set("library", library)
	_add(root, crunch)
	# Layered clarity (task-066): pushable objects are layered boxes of the world view.
	glyph_view.set("pushables", pushables)

	# Teleports (task-068): the trip logic (watches the player's cell, owns the timeline, moves the body) and its
	# presentation (pad frames, colour waves on the world material, camera travel through the rig).
	var teleport_cfg: TeleportConfig = load(CFG + "teleport_config.tres")
	var teleports: Node = load("res://scripts/world/teleport_system.gd").new()
	teleports.name = "TeleportSystem"
	teleports.set("config", teleport_cfg)
	teleports.set("map_loader", loader)
	teleports.set("player", player)
	teleports.set("run_manager", runs)
	teleports.set("destructibles", destructibles)
	_add(root, teleports)
	var teleport_view: Node3D = load("res://scripts/rendering/teleport_view.gd").new()
	teleport_view.name = "TeleportView"
	teleport_view.set("config", teleport_cfg)
	teleport_view.set("map_loader", loader)
	teleport_view.set("map_reveal", reveal)
	teleport_view.set("camera_rig", rig)
	teleport_view.set("surface_material", load(GLYPH_MATERIAL))
	_add(root, teleport_view)

	# Enemies (task-075): the only writer of the enemy state (moves, contact deaths, Destructibles kind "enemy") and
	# their glyph creatures; remains (task-076): diamonds and black holes, their look and the pickup sound.
	var enemy_cfg: EnemyConfig = load(CFG + "enemy_config.tres")
	var remains_cfg: RemainsConfig = load(CFG + "remains_config.tres")
	var enemies: Node = load("res://scripts/world/enemy_system.gd").new()
	enemies.name = "EnemySystem"
	enemies.set("config", enemy_cfg)
	enemies.set("map_loader", loader)
	enemies.set("player", player)
	enemies.set("player_config", player_cfg)
	enemies.set("run_manager", runs)
	enemies.set("destructibles", destructibles)
	enemies.set("pushables", pushables)
	enemies.set("database", database)
	_add(root, enemies)
	var remains: Node = load("res://scripts/world/enemy_remains.gd").new()
	remains.name = "EnemyRemains"
	remains.set("config", remains_cfg)
	remains.set("enemies", enemies)
	remains.set("map_loader", loader)
	remains.set("player", player)
	remains.set("save_service", save)
	remains.set("run_manager", runs)
	_add(root, remains)
	enemies.set("remains", remains)
	var enemy_view: Node3D = load("res://scripts/rendering/enemy_view.gd").new()
	enemy_view.name = "EnemyView"
	enemy_view.set("config", enemy_cfg)
	enemy_view.set("enemies", enemies)
	enemy_view.set("map_loader", loader)
	enemy_view.set("map_reveal", reveal)
	_add(root, enemy_view)
	var remains_view: Node3D = load("res://scripts/rendering/remains_view.gd").new()
	remains_view.name = "RemainsView"
	remains_view.set("config", remains_cfg)
	remains_view.set("remains", remains)
	remains_view.set("map_loader", loader)
	remains_view.set("map_reveal", reveal)
	_add(root, remains_view)
	var ting: Node = load("res://scripts/world/diamond_sfx.gd").new()
	ting.name = "DiamondSfx"
	ting.set("config", remains_cfg)
	ting.set("library", library)
	_add(root, ting)

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

	# Gargoyle fountain hidden message (task-092): a language-dependent line near a standing fountain.
	var whisper: Node = load("res://scripts/world/fountain_whisper.gd").new()
	whisper.name = "FountainWhisper"
	whisper.set("map_loader", loader)
	whisper.set("player", player)
	whisper.set("language", language)
	_add(root, whisper)

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
