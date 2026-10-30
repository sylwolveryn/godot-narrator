extends SceneTree
## Builds the config .tres instances in res://resources/config/. Idempotent.
## Usage: godot --headless --path . -s tools/build_resources.gd

const DIR := "res://resources/config/"


func _init() -> void:
	var ok := true
	ok = _save(RunConfig.new(), "run_config.tres") and ok
	ok = _save(WorldConfig.new(), "world_config.tres") and ok
	ok = _save(AsciiConfig.new(), "ascii_config.tres") and ok
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

	var legend := MapLegend.new()
	legend.hazards[MapLegend.SPIKES] = load(DIR + "hazard_spikes.tres") as HazardDefinition
	legend.hazards[MapLegend.CORRUPT] = load(DIR + "hazard_corrupting.tres") as HazardDefinition
	ok = _save(legend, "map_legend.tres") and ok
	ok = _save(SaveConfig.new(), "save_config.tres") and ok
	ok = _save(GlyphFxConfig.new(), "glyph_fx_config.tres") and ok
	ok = _save(IntroConfig.new(), "intro_config.tres") and ok
	ok = _save(RevealConfig.new(), "reveal_config.tres") and ok

	var pool := IdentityPool.new()
	ok = _save(pool, "identity_pool.tres") and ok
	var player_cfg := PlayerConfig.new()
	player_cfg.identity_pool = load(DIR + "identity_pool.tres") as IdentityPool
	ok = _save(player_cfg, "player_config.tres") and ok

	var top_down := CameraViewConfig.new()
	ok = _save(top_down, "camera_top_down.tres") and ok

	var tilted := CameraViewConfig.new()
	tilted.orthographic = false
	tilted.pitch_degrees = -55.0
	tilted.distance = 14.0
	ok = _save(tilted, "camera_tilted.tres") and ok

	quit(0 if ok else 1)


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
