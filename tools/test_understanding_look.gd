extends SceneTree
## Tests the look that follows the selected language's understanding (task-066) on the real main scene with the arena
## map: the world clarity uniform and layer map (GlyphWorldView), the gargoyle silhouette backing (LargeObjectView),
## and the player glyph (hollow and glow-less below 6%, glow rising to the full look at 100%, blunt colour at 0 and a
## bit more vivid than the plain look at 1, the grown body following). Understanding 0 must keep every world uniform
## as it was before the feature. The test emits SignalBus.language_understanding_changed itself.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_understanding_look.gd

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "understanding_look"
const ARENA := "res://data/maps/m2_arena.txt"
const PHASE_PLAYING := 1
const LANGUAGE: StringName = &"EN_GB"
## Layer map encoding (GlyphWorldView.LAYER_TYPES / LAYER_CODE).
const LAYER_TYPES := 8
const LAYER_CODE := 255.0
const EPS := 0.0001
## Arena floor cell two cells above the 3x2 gargoyle fountain (21..23, 14..15).
const GARGOYLE_VIEW_CELL := Vector2i(22, 12)

var _failures: PackedStringArray = []
var _bus: Node


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _near(a: float, b: float) -> bool:
	return absf(a - b) < EPS


func _wait(seconds: float) -> void:
	var start: int = Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) / 1000.0 < seconds:
		await process_frame


func _run() -> void:
	_check_config()
	await _check_scene()
	if _failures.is_empty():
		print("PASS test_understanding_look")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_understanding_look")
		quit(1)


func _emit(value: float) -> void:
	_bus.emit_signal(&"language_understanding_changed", LANGUAGE, value)


func _check_config() -> void:
	var fx := AvatarFxConfig.new()
	_check(_near(fx.hollow_at(0.0), 1.0) and _near(fx.hollow_at(0.05), 1.0), "hollow below 6%")
	_check(_near(fx.hollow_at(0.5), 0.0) and _near(fx.hollow_at(1.0), 0.0), "filled from 6% + fill_fade")
	_check(_near(fx.glow_at(0.0), 0.0) and _near(fx.glow_at(0.05), 0.0) and _near(fx.glow_at(fx.glow_start), 0.0), "no glow below 6%")
	_check(fx.glow_at(0.3) > 0.0 and fx.glow_at(0.3) < fx.glow_at(0.6) and _near(fx.glow_at(1.0), 1.0), "glow rises to 1 at 100%")
	var blunt: Vector2 = fx.colour_grade_at(0.0)
	var vivid: Vector2 = fx.colour_grade_at(1.0)
	_check(blunt.x < 1.0 and blunt.y < 1.0, "blunt colour at 0, got %s" % blunt)
	_check(vivid.x > 1.0 and vivid.y > 1.0 and vivid.x <= 1.2 and vivid.y <= 1.2, "slightly more vivid at 1, got %s" % vivid)
	var row: AvatarFxConfig = fx.with_row({"hollow_below": 0.1, "vivid_brightness": 1.05})
	_check(_near(row.hollow_below, 0.1) and _near(row.vivid_brightness, 1.05), "DB row may override the look values")


func _snapshot(mat: ShaderMaterial) -> Dictionary:
	var out: Dictionary = {}
	for p: Dictionary in mat.shader.get_shader_uniform_list():
		var key: StringName = p["name"]
		out[key] = mat.get_shader_parameter(key)
	return out


func _check_scene() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	Support.isolate_save(main, SAVE_TAG)
	var intro := IntroConfig.new()
	intro.black_hold = 0.05
	intro.wave_fade_in = 0.05
	intro.wave_hold = 0.05
	intro.reveal_duration = 0.05
	main.get_node("IntroSequence").set("config", intro)
	var loader: MapLoader = main.get_node("World/MapLoader")
	loader.map_path = ARENA
	loader.use_cmdline_map = false
	root.add_child(main)
	_bus = root.get_node("SignalBus")
	await _wait(0.6)
	_check(main.get_node("RunManager").get("phase") == PHASE_PLAYING, "run should be playing")

	# --- world clarity ---
	var world_view: Node = main.get_node("GlyphWorldView")
	var wmat: ShaderMaterial = world_view.get("material")
	_emit(0.0)
	_check(_near(float(wmat.get_shader_parameter(&"clarity")), 0.0), "clarity 0 at understanding 0")
	var before: Dictionary = _snapshot(wmat)
	_emit(0.5)
	var cfg: GlyphWorldConfig = world_view.get("config")
	_check(_near(float(wmat.get_shader_parameter(&"clarity")), pow(0.5, cfg.clarity_exponent)), "clarity follows the understanding")
	_emit(1.0)
	_check(_near(float(wmat.get_shader_parameter(&"clarity")), 1.0), "clarity 1 at understanding 1")
	_emit(0.0)
	var after: Dictionary = _snapshot(wmat)
	for key: StringName in before:
		if key == &"light_pos" or key == &"light_col" or key == &"light_count" or key == &"vis_params":
			continue   # moved by the player light and the static light fades, not by the understanding
		_check(str(before[key]) == str(after[key]), "understanding 0 restores uniform %s" % key)
	_check_layer_map(world_view, loader)

	# --- gargoyle backing ---
	var large: Node = main.get_node("LargeObjectView")
	var player: CharacterBody3D = main.get_node("Player")
	player.velocity = Vector3.ZERO
	player.global_position = loader.cell_to_world(GARGOYLE_VIEW_CELL)
	await _wait(1.2)
	_emit(0.0)   # walking / revealing tiles lets LanguageProgress announce its own (small) understanding
	_check(int(large.call("piece_count")) > 0, "the arena has gargoyles")
	var shown: int = -1
	for i in int(large.call("piece_count")):
		if bool(large.call("piece_visible", i)):
			shown = i
			break
	if shown >= 0:
		var backing: Label3D = large.call("piece_backing", shown)
		# Task-101: a statue is a solid body, its backing is always opaque; flat art follows the understanding.
		var statue: bool = large.call("piece_is_statue", shown)
		_check(backing.visible == statue, "backing at understanding 0: %s for a %s" % [backing.visible, "statue" if statue else "flat art"])
		_emit(1.0)
		_check(backing.visible and backing.modulate.a > 0.99, "opaque backing at understanding 1")
		_check(backing.render_priority < (large.call("piece_labels", shown) as Array)[0].render_priority, "backing sorts behind the art")
		_check(backing.text.contains(large.get("backing_char")), "backing text is the silhouette")
		_emit(0.5)
		if statue:
			_check(backing.visible and backing.modulate.a > 0.99, "statue backing stays opaque at 0.5")
		else:
			_check(backing.visible and backing.modulate.a > 0.4 and backing.modulate.a < 0.6, "half backing at 0.5")
	else:
		_failures.append("no gargoyle seen from the arena spawn")

	# --- player glyph ---
	var view: Node = main.get_node("PlayerGlyphView")
	var pmat: ShaderMaterial = (view.get_node("Actors") as MultiMeshInstance3D).material_override
	var fx: AvatarFxConfig = view.call("avatar_fx")
	var glyph_fx: GlyphFxConfig = view.get("fx_config")
	var body: ShaderMaterial = (view.call("entity_body") as Node).call("body_material")
	for u: float in [0.0, 0.05]:
		_emit(u)
		_check(_near(float(pmat.get_shader_parameter(&"hollow")), 1.0), "hollow at %.2f" % u)
		_check(_near(float(pmat.get_shader_parameter(&"halo_intensity")), 0.0), "no halo at %.2f" % u)
		_check(_near(float(pmat.get_shader_parameter(&"crystal_strength")), 0.0), "no crystal at %.2f" % u)
		_check(_near(float(pmat.get_shader_parameter(&"crystal_sparkle")), 0.0), "no sparkle at %.2f" % u)
		_check(_near(float(body.get_shader_parameter(&"hollow")), 1.0), "grown body hollow at %.2f" % u)
	_emit(0.0)
	_check(_near(float(pmat.get_shader_parameter(&"face_saturation")), fx.blunt_saturation), "blunt saturation at 0")
	_check(_near(float(pmat.get_shader_parameter(&"face_brightness")), fx.blunt_brightness), "blunt brightness at 0")
	_check(_near(float(body.get_shader_parameter(&"face_saturation")), fx.blunt_saturation), "grown body blunt at 0")
	_emit(0.5)
	var halo_half: float = pmat.get_shader_parameter(&"halo_intensity")
	_check(_near(float(pmat.get_shader_parameter(&"hollow")), 0.0), "filled at 0.5")
	_check(halo_half > 0.0 and halo_half < glyph_fx.halo_intensity, "halo between none and full at 0.5, got %f" % halo_half)
	var sat_half: float = pmat.get_shader_parameter(&"face_saturation")
	_check(sat_half > fx.blunt_saturation and sat_half < fx.vivid_saturation, "colour between blunt and vivid at 0.5")
	_emit(1.0)
	_check(_near(float(pmat.get_shader_parameter(&"halo_intensity")), glyph_fx.halo_intensity), "today's halo at 1")
	_check(_near(float(pmat.get_shader_parameter(&"crystal_strength")), fx.crystal_strength), "today's crystal at 1")
	_check(_near(float(pmat.get_shader_parameter(&"crystal_sparkle")), fx.crystal_sparkle), "today's sparkle at 1")
	_check(float(pmat.get_shader_parameter(&"face_saturation")) > 1.0 and float(pmat.get_shader_parameter(&"face_brightness")) > 1.0, "more vivid than plain at 1")
	_check(_near(float(body.get_shader_parameter(&"hollow")), 0.0), "grown body filled at 1")
	# A DB reload keeps the understanding look (the crystal values are re-scaled, not reset).
	var db: Node = main.get_node("GameDatabase")
	_emit(0.0)
	db.emit_signal("tables_loaded", (db.get("tables") as Dictionary).duplicate(true))
	_check(_near(float(pmat.get_shader_parameter(&"crystal_strength")), 0.0), "reload keeps the glow off at 0")

	main.queue_free()
	await process_frame
	Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)


## Every item / spike / corruption cell of the map is a layered box with its order; plain floor far from them is not.
func _check_layer_map(world_view: Node, loader: MapLoader) -> void:
	var tex: ImageTexture = world_view.call("layer_texture")
	_check(tex != null, "layer map built")
	if tex == null:
		return
	var img: Image = world_view.call("layer_image")
	var map: MapData = loader.data
	var cfg: GlyphWorldConfig = world_view.get("config")
	var kinds: Dictionary = {MapLegend.ITEM: GlyphSurfaceType.ITEM, MapLegend.SPIKES: GlyphSurfaceType.SPIKES}
	var found: int = 0
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			var type: StringName = map.type_at(c)
			if kinds.has(type):
				var st: int = kinds[type]
				var code: int = int(img.get_pixelv(c).r * LAYER_CODE + 0.5)
				_check(code == cfg.layer_order[st] * LAYER_TYPES + st, "layer code of %s at %s, got %d" % [type, c, code])
				_check(img.get_pixelv(c).a > 0.5, "layered cell %s runs the owner search" % c)
				found += 1
	_check(found > 0, "the arena has items and spikes")
	var pushables: Node = world_view.get("pushables")
	_check(pushables != null and int(pushables.call("count")) > 0, "the world view knows the pushable objects")
	if pushables != null and int(pushables.call("count")) > 0:
		var oc: int = int(img.get_pixelv(pushables.call("cell_of", 0)).r * LAYER_CODE + 0.5)
		_check(oc == cfg.layer_order[GlyphSurfaceType.WALL] * LAYER_TYPES + GlyphSurfaceType.WALL, "pushable object is layered, got %d" % oc)
