extends SceneTree
## Builds the origin rule-out resources (task-039). Idempotent. Run before build_narration.gd and build_main_scene.gd.
##   resources/origin/trial_<nature>.tres   OriginTrial per nature
##   resources/origin/<id>.tres             OriginHypothesis (4 natures, 2 deeds)
##   resources/config/origin_config.tres    OriginConfig
## Usage: godot --headless --path . --max-fps 30 -s tools/build_origin.gd

const DIR := "res://resources/origin/"
const CONFIG_PATH := "res://resources/config/origin_config.tres"


func _init() -> void:
	var ok := true
	DirAccess.make_dir_recursive_absolute(DIR)

	var erosion := OriginTrial.new()
	erosion.kind = OriginTrial.Kind.EROSION_ESCAPE
	erosion.seconds = 15.0
	erosion.erosion_fraction = 0.7
	var single := OriginTrial.new()
	single.kind = OriginTrial.Kind.SINGLE_FORM_SURVIVE
	single.seconds = 60.0
	var dark := OriginTrial.new()
	dark.kind = OriginTrial.Kind.DARK_IDLE
	dark.seconds = 20.0
	dark.distance = 6
	var moved := OriginTrial.new()
	moved.kind = OriginTrial.Kind.OBJECT_MOVED
	moved.requires_entity_unlocked = true

	var trials: Dictionary = {&"demonic": erosion, &"ai": single, &"angelic": dark, &"alien": moved}
	var natures: Array = [
		[&"alien", "*", "the stars"],
		[&"ai", "#", "the machine"],
		[&"demonic", "^", "the name"],
		[&"angelic", "+", "the light"],
	]
	var deeds: Array = [
		[&"hero", "!", "the hero"],
		[&"villain", "x", "the villain"],
	]
	var list: Array[OriginHypothesis] = []
	for row: Array in natures:
		var id: StringName = row[0]
		var trial_path := DIR + "trial_%s.tres" % id
		ok = _save(trials[id], trial_path) and ok
		list.append(_hypothesis(id, OriginHypothesis.Axis.NATURE, row[1], row[2], load(trial_path) as OriginTrial))
	for row: Array in deeds:
		list.append(_hypothesis(row[0], OriginHypothesis.Axis.DEED, row[1], row[2], null))

	var saved: Array[OriginHypothesis] = []
	for h in list:
		var path := DIR + "%s.tres" % h.id
		ok = _save(h, path) and ok
		saved.append(load(path) as OriginHypothesis)
	var config := OriginConfig.new()
	config.hypotheses = saved
	ok = _save(config, CONFIG_PATH) and ok
	quit(0 if ok else 1)


func _hypothesis(id: StringName, axis: OriginHypothesis.Axis, sigil: String, label: String, trial: OriginTrial) -> OriginHypothesis:
	var h := OriginHypothesis.new()
	h.id = id
	h.axis = axis
	h.sigil = sigil
	h.label = label
	h.trial = trial
	if axis == OriginHypothesis.Axis.NATURE:
		# Conventional ids; the beats themselves are authored in task-044.
		h.claim_beat_id = "claim_%s" % id
		h.broken_beat_id = "broken_%s" % id
		h.recant_beat_id = "recant_%s" % id
	return h


func _save(res: Resource, path: String) -> bool:
	var uid := ResourceLoader.get_resource_uid(path)
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s: %s" % [path, error_string(err)])
		return false
	if uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(path, uid)
	print("Saved ", path)
	return true
