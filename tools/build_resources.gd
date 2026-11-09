extends SceneTree
## Builds the config .tres instances in res://resources/config/. Idempotent.
## Usage: godot --headless --path . -s tools/build_resources.gd

const DIR := "res://resources/config/"
## Multi-cell prop definitions (task-058), relative to DIR.
const LARGE_DIR := "large_objects/"


func _init() -> void:
	var ok := true
	ok = _save(RunConfig.new(), "run_config.tres") and ok
	ok = _save(WorldConfig.new(), "world_config.tres") and ok
	ok = _save(DisplayConfig.new(), "display_config.tres") and ok

	var spikes := HazardDefinition.new()
	spikes.kind = MapLegend.SPIKES
	spikes.end_cause = &"spikes"
	spikes.lethal_on_touch = true
	spikes.tint = Color(1.0, 0.3, 0.25)
	ok = _save(spikes, "hazard_spikes.tres") and ok
	var corrupting := HazardDefinition.new()
	corrupting.kind = MapLegend.CORRUPT
	corrupting.end_cause = &"corruption"
	corrupting.erosion_rate = 1.0
	corrupting.erosion_threshold = 2.5
	corrupting.recovery_rate = 0.8
	corrupting.tint = Color(0.85, 0.25, 0.95)
	ok = _save(corrupting, "hazard_corrupting.tres") and ok

	# Multi-cell props (task-058): one LargeObjectDef per prop, registered in the legend by its type.
	DirAccess.make_dir_recursive_absolute(DIR + LARGE_DIR)
	ok = _save(_gargoyle_fountain(), LARGE_DIR + "gargoyle_fountain.tres") and ok
	ok = _save(_cannon(), LARGE_DIR + "cannon.tres") and ok

	var legend := MapLegend.new()
	legend.hazards[MapLegend.SPIKES] = load(DIR + "hazard_spikes.tres") as HazardDefinition
	legend.hazards[MapLegend.CORRUPT] = load(DIR + "hazard_corrupting.tres") as HazardDefinition
	var gargoyle: LargeObjectDef = load(DIR + LARGE_DIR + "gargoyle_fountain.tres") as LargeObjectDef
	legend.large_objects[gargoyle.type] = gargoyle
	var cannon: LargeObjectDef = load(DIR + LARGE_DIR + "cannon.tres") as LargeObjectDef
	legend.large_objects[cannon.type] = cannon
	ok = _save(legend, "map_legend.tres") and ok
	ok = _save(SaveConfig.new(), "save_config.tres") and ok
	ok = _save(GlyphFxConfig.new(), "glyph_fx_config.tres") and ok
	ok = _save(IntroConfig.new(), "intro_config.tres") and ok
	ok = _save(RevealConfig.new(), "reveal_config.tres") and ok
	ok = _save(PushConfig.new(), "push_config.tres") and ok

	var pool := IdentityPool.new()
	ok = _save(pool, "identity_pool.tres") and ok
	var player_cfg := PlayerConfig.new()
	player_cfg.identity_pool = load(DIR + "identity_pool.tres") as IdentityPool
	ok = _save(player_cfg, "player_config.tres") and ok

	var iso := CameraViewConfig.new()
	iso.orthographic = true
	iso.size = 12.6
	iso.pitch_degrees = -35.264
	iso.yaw_degrees = 45.0
	iso.look_height = 0.6
	iso.distance = 30.0
	iso.near = 1.0
	iso.far = 80.0
	ok = _save(iso, "camera_isometric.tres") and ok

	ok = _save(GlyphWorldConfig.new(), "glyph_world_config.tres") and ok

	var tilted := CameraViewConfig.new()
	tilted.orthographic = false
	tilted.pitch_degrees = -55.0
	tilted.distance = 14.0
	ok = _save(tilted, "camera_tilted.tres") and ok

	# Data layer (task-048): SpacetimeDB link and the narration file lookup.
	ok = _save(DbConfig.new(), "db_config.tres") and ok
	ok = _save(NarrationLibraryConfig.new(), "narration_library_config.tres") and ok
	ok = _save(GlyphAnimConfig.new(), "glyph_anim_config.tres") and ok
	ok = _save(AvatarFxConfig.new(), "avatar_fx_config.tres") and ok
	# Language understanding progression (task-065).
	ok = _save(LanguageConfig.new(), "language_config.tres") and ok
	# Teleports (task-068): trip timeline, camera drive, colour waves, pad look.
	ok = _save(TeleportConfig.new(), "teleport_config.tres") and ok
	ok = _save(DirtConfig.new(), "dirt_config.tres") and ok
	# Interact control (task-072) and the cannon (task-073).
	ok = _save(InteractConfig.new(), "interact_config.tres") and ok
	ok = _save(_cannon_config(), "cannon_config.tres") and ok
	# Enemies (task-075) and their remains (task-076).
	ok = _save(_enemy_config(), "enemy_config.tres") and ok
	ok = _save(RemainsConfig.new(), "remains_config.tres") and ok
	# Death marks (task-093): stains, the invulnerability item and the shield aura.
	ok = _save(DeathMarksConfig.new(), "death_marks_config.tres") and ok

	quit(0 if ok else 1)


## The gargoyle fountain `G` (task-058): a horned, winged gargoyle spitting a stream into a basin. Layers: " " stone,
## "e" glowing eyes, "w" the falling stream, "s" the basin water (both animated).
func _gargoyle_fountain() -> LargeObjectDef:
	var def := LargeObjectDef.new()
	def.type = &"gargoyle"
	def.character = "G"
	def.art_lines = PackedStringArray([
		"   /\\          /\\   ",
		"  /##\\  ____  /##\\  ",
		" /####\\/@  @\\/####\\ ",
		"/######( vv )######\\",
		"\\##/ \\##\\__/##/ \\##/",
		" \\/   \\##||##/   \\/ ",
		"       |#||#|       ",
		"  .____\\#||#/____.  ",
		" /  : ' :||: ' :  \\ ",
		"|~~~~~~~~~~~~~~~~~~|",
		"|##################|",
		" \\################/ ",
	])
	def.mask_lines = PackedStringArray([
		"",
		"",
		"        e  e",
		"",
		"",
		"         ww",
		"         ww",
		"         ww",
		"    s s swws s s",
		" ssssssssssssssssss",
	])
	def.art_width_ratio = 1.3
	def.outline_size = 10
	def.outline_color = Color(0.01, 0.01, 0.03, 0.95)
	def.base_color = Color(0.58, 0.6, 0.9)
	def.layer_colors = {
		"e": Color(1.0, 0.18, 0.22),
		"w": Color(0.55, 0.9, 1.0),
		"s": Color(0.25, 0.65, 1.0),
	}
	def.layer_anims = {
		"w": "|:|'|.",
		"s": "~-~=~-",
	}
	def.anim_fps = 5.0
	# Task-073: a cannon ball destroys the whole fountain.
	def.destructible = true
	return def


## The cannon `C` (task-073): merged like the gargoyle (1x1, 2x2 ...). No art here: CannonView draws it per facing
## (CannonConfig.art). Solid, indestructible (balls bounce off it), low enough not to hide or shade what is behind it.
func _cannon() -> LargeObjectDef:
	var def := LargeObjectDef.new()
	def.type = &"cannon"
	def.character = "C"
	def.height = 0.8
	def.blocks_movement = true
	def.blocks_sight = false
	def.blocks_light = false
	def.destructible = false
	return def


## Cannon numbers and the barrel art per screen direction (0 = right, clockwise on screen): body `(###)` on wheels
## `o---o`, barrel `=` / `H` / `/` / `\` ending in the muzzle `O`.
func _cannon_config() -> CannonConfig:
	var cfg := CannonConfig.new()
	cfg.art = [
		PackedStringArray(["         ", "         ", "  (###)=O", "  o---o  ", "         "]),
		PackedStringArray(["         ", "         ", "  (###)  ", "  o---o\\ ", "        O"]),
		PackedStringArray(["         ", "         ", "  (###)  ", "  o-H-o  ", "    O    "]),
		PackedStringArray(["         ", "         ", "  (###)  ", " /o---o  ", "O        "]),
		PackedStringArray(["         ", "         ", "O=(###)  ", "  o---o  ", "         "]),
		PackedStringArray(["O        ", " \\       ", "  (###)  ", "  o---o  ", "         "]),
		PackedStringArray(["    O    ", "    H    ", "  (###)  ", "  o---o  ", "         "]),
		PackedStringArray(["        O", "       / ", "  (###)  ", "  o---o  ", "         "]),
	]
	return cfg


## The three enemy types (task-075; gameplay numbers are overridden by the DB table enemy_def):
##  - crawler (L / R): a scuttling bug `Ж` with legs `<` `>`, amber; bursts into 3 diamonds.
##  - hunter (H): a red `Ω` with two glowing eyes; leaves a black hole.
##  - wanderer (W): a green `&` with a slowly orbiting tail of dots; bursts into 2 diamonds.
func _enemy_config() -> EnemyConfig:
	var cfg := EnemyConfig.new()
	var crawler := EnemyDef.new()
	crawler.kind = &"crawler"
	crawler.movement = EnemyDef.Movement.CRAWLER
	crawler.speed = 2.2
	crawler.diamonds = 3
	crawler.glyphs = "Ж<>"
	crawler.color = Color(1.0, 0.62, 0.18)
	crawler.accent = Color(1.0, 0.85, 0.45)
	crawler.satellite_radius = 0.3
	crawler.satellite_start_degrees = 180.0
	crawler.satellite_step_degrees = 180.0
	crawler.wiggle_amount = 0.07
	crawler.wiggle_hz = 7.0
	crawler.bob_amount = 0.03
	crawler.hover = 0.36
	var hunter := EnemyDef.new()
	hunter.kind = &"hunter"
	hunter.movement = EnemyDef.Movement.HUNTER
	hunter.speed = 2.6
	hunter.black_hole = true
	hunter.glyphs = "Ω••"
	hunter.color = Color(1.0, 0.2, 0.3)
	hunter.accent = Color(1.0, 0.95, 0.4)
	hunter.body_size = 0.36
	hunter.satellite_scale = 0.4
	hunter.satellite_radius = 0.2
	hunter.satellite_start_degrees = 60.0
	hunter.satellite_step_degrees = 60.0
	hunter.wiggle_amount = 0.02
	hunter.wiggle_hz = 2.0
	hunter.bob_amount = 0.06
	hunter.hover = 0.5
	hunter.glow = 0.5
	var wanderer := EnemyDef.new()
	wanderer.kind = &"wanderer"
	wanderer.movement = EnemyDef.Movement.WANDERER
	wanderer.speed = 1.8
	wanderer.diamonds = 2
	wanderer.glyphs = "&°·°"
	wanderer.color = Color(0.35, 1.0, 0.6)
	wanderer.accent = Color(0.7, 1.0, 0.95)
	wanderer.satellite_scale = 0.5
	wanderer.satellite_radius = 0.36
	wanderer.satellite_start_degrees = 0.0
	wanderer.satellite_step_degrees = 120.0
	wanderer.orbit_degrees_per_second = 90.0
	wanderer.wiggle_amount = 0.04
	wanderer.wiggle_hz = 1.5
	wanderer.bob_amount = 0.08
	wanderer.bob_hz = 0.9
	wanderer.hover = 0.5
	cfg.defs = [crawler, hunter, wanderer] as Array[EnemyDef]
	return cfg


func _save(res: Resource, file: String) -> bool:
	var path := DIR + file
	DirAccess.make_dir_recursive_absolute(DIR)
	# Reuse existing file uid when present so references stay valid.
	var uid := ResourceLoader.get_resource_uid(path)
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s: %s" % [path, error_string(err)])
		return false
	if uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(path, uid)
	print("Saved ", path)
	return true
