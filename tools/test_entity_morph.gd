extends SceneTree
## Headless test of task-099: the many form's slow shape morph (EntityMorph). The shipped config has a human base and
## the lion head, angelic and hand shapes; every shape resolves to the same slots (hidden duplicates where it has fewer
## glyphs) with the heart cell fixed; the clock holds, morphs 30-50 s, and always returns to the human between the
## other shapes, never repeating the one just shown; the collider ignores the morph; EntityGlyphView writes the shapes
## and drives the `morph` uniform.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_entity_morph.gd

const CONFIG := "res://resources/config/entity_growth_config.tres"
const STEP := 0.5
const EPS := 0.0001

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	var cfg: EntityGrowthConfig = load(CONFIG)
	_check(cfg.formations.size() == 1 and cfg.formations[0].id == &"human", "the base formation is the human")
	var ids: Array = cfg.morph_shapes.map(func(f: EntityFormation) -> StringName: return f.id)
	_check(ids.has(&"lion_head") and ids.has(&"angelic") and ids.has(&"hand"), "morph shapes: lion head, angelic, hand (%s)" % [ids])
	_check(cfg.morph_duration_min >= 30.0 and cfg.morph_duration_max <= 50.0, "a transformation takes 30-50 s")

	var ext: Vector2 = cfg.body_extents_for("Q")
	_check(ext.x * 2.0 > 1.7 and ext.x * 2.0 < 2.3 and ext.y * 2.0 > 2.7 and ext.y * 2.0 < 3.3, "the human is ~2 x 3 tiles (%s)" % (ext * 2.0))

	var m: EntityMorph = EntityMorph.build(cfg, "Q")
	var n: int = m.slot_count()
	_check(m.shapes.size() == 4 and n > 0, "four shapes, %d slots" % n)
	for k in m.shapes.size():
		var s: EntityMorph.Shape = m.shapes[k]
		var shown: int = 0
		for v in s.visible:
			shown += v
		var f: EntityFormation = cfg.formations[0] if k == 0 else cfg.morph_shapes[k - 1]
		_check(s.offsets.size() == n and s.glyphs.size() == n, "shape %s has every slot" % s.id)
		_check(shown == f.glyph_count(), "shape %s shows its %d glyphs (%d)" % [s.id, f.glyph_count(), shown])
		var half: Vector2 = Vector2(3.0 * f.advance.x, 5.0 * f.advance.y) + Vector2.ONE * EPS
		var inside: bool = true
		for o in s.offsets:
			inside = inside and absf(o.x) <= half.x and absf(o.y) <= half.y
		_check(inside, "shape %s stays in the 2 x 3 tile body" % s.id)
	var again: EntityMorph = EntityMorph.build(cfg, "Q")
	_check(again.shapes[0].glyphs == m.shapes[0].glyphs, "the same identity gives the same body glyphs")
	for g in m.shapes[0].glyphs:
		_check(cfg.body_glyphs.contains(g), "the human is made of the identity's body glyphs ('%s')" % g)
		break

	# Clock: hold the base, morph to another shape, hold, morph back; never the same other shape twice in a row.
	var seq: Array[int] = []
	var morph_lengths: Array[float] = []
	var changes: int = 0
	var last_progress: float = 0.0
	var monotonic: bool = true
	var t: float = 0.0
	while t < 1200.0:
		var was_morph: bool = m.phase == EntityMorph.Phase.MORPH
		if m.step(STEP):
			changes += 1
			if m.phase == EntityMorph.Phase.MORPH:
				seq.append(m.to_index)
				morph_lengths.append(m.length)
				last_progress = 0.0
		elif was_morph:
			var p: float = m.progress()
			monotonic = monotonic and p >= last_progress - EPS
			last_progress = p
		t += STEP
	_check(changes > 4, "the body keeps morphing (%d changes in 20 min)" % changes)
	_check(monotonic, "a morph glides one way (progress never goes back)")
	var ok_seq: bool = seq.size() >= 4
	for i in seq.size():
		var want_base: bool = i % 2 == 1
		ok_seq = ok_seq and (seq[i] == 0) == want_base
	_check(ok_seq, "human -> shape -> human -> shape ... (%s)" % [seq])
	var others: Array[int] = []
	for i in range(0, seq.size(), 2):
		others.append(seq[i])
	var repeats: bool = false
	for i in range(1, others.size()):
		repeats = repeats or others[i] == others[i - 1]
	_check(not repeats and others.has(1) and others.has(2) and others.has(3), "every shape shows, never twice in a row (%s)" % [others])
	var lengths_ok: bool = true
	for l in morph_lengths:
		lengths_ok = lengths_ok and l >= cfg.morph_duration_min and l <= cfg.morph_duration_max
	_check(lengths_ok, "every transformation takes 30-50 s")
	_check(is_equal_approx(cfg.body_extents_for("Q").y, ext.y), "the collider ignores the morph")

	# The view writes both shapes and drives the uniform.
	# Loaded at run time: the view's script needs the SignalBus autoload to compile.
	var view: Node3D = (load("res://scripts/rendering/entity_glyph_view.gd") as GDScript).new()
	view.set("config", cfg)
	root.add_child(view)
	view.call("use_identity", "Q")
	view.call("set_form", EntityForm.GROWN, false)
	_check(view.call("slot_count") == n and view.call("glyph_count") == cfg.formations[0].glyph_count(), "view: slots and base glyphs")
	var vm: EntityMorph = view.call("morph")
	vm.time = vm.length
	view.call("present", 0.01, Vector3.ZERO, 0.0, Color.WHITE, true)
	_check(vm.phase == EntityMorph.Phase.MORPH, "view: the morph starts after the hold")
	vm.time = vm.length * 0.5
	view.call("present", 0.0, Vector3.ZERO, 0.0, Color.WHITE, true)
	var u: float = float((view.call("body_material") as ShaderMaterial).get_shader_parameter(&"morph"))
	_check(absf(u - 0.5) < 0.01, "view: half way through, morph uniform ~0.5 (%s)" % u)
	_check(float(view.call("heart_scale")) < 1.0, "view: the heart shrinks into the small body")
	view.queue_free()
	await process_frame

	if _failures.is_empty():
		print("PASS test_entity_morph")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_entity_morph")
		quit(1)
