extends SceneTree
## Builds the multi-glyph entity resources (task-017): the formations in res://resources/config/formations/ and
## res://resources/config/entity_growth_config.tres. Idempotent. Edit the patterns here, then rebuild.
## Pattern key: '@' = the heart (identity glyph), '.' = empty, '*' = filler glyph (seeded by identity), other = itself.
## Usage: godot --headless --path . -s tools/build_entity_growth.gd

const DIR := "res://resources/config/"
const FORMATION_DIR := "res://resources/config/formations/"

const WINGED: PackedStringArray = [
	"..^...^..",
	".<*\\|/*>.",
	"<**(@)**>",
	".<*/|\\*>.",
	"...V.V...",
]
const BEETLE: PackedStringArray = [
	".\\_____/.",
	"-[*###*]-",
	"=<*(@)*>=",
	"-[*###*]-",
	".//...\\\\.",
]
const SPRITE: PackedStringArray = [
	"..^.^..",
	".(***).",
	"-(*@*)-",
	".(***).",
	"..V.V..",
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FORMATION_DIR))
	var ok := true
	var formations: Array[EntityFormation] = []
	for spec in [[&"winged", WINGED], [&"beetle", BEETLE], [&"sprite", SPRITE]]:
		var f := EntityFormation.new()
		f.id = spec[0]
		f.rows = spec[1]
		var path: String = "%s%s.tres" % [FORMATION_DIR, spec[0]]
		ok = _save(f, path) and ok
		formations.append(load(path) as EntityFormation)
	var config := EntityGrowthConfig.new()
	config.formations = formations
	ok = _save(config, DIR + "entity_growth_config.tres") and ok
	quit(0 if ok else 1)


func _save(res: Resource, path: String) -> bool:
	var err: Error = ResourceSaver.save(res, path)
	if err != OK:
		push_error("Could not save %s: %s" % [path, error_string(err)])
		return false
	print("Saved ", path)
	return true
