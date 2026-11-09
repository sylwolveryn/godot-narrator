extends SceneTree
## Builds the multi-glyph entity resources (task-017, task-099): the formations in res://resources/config/formations/
## and res://resources/config/entity_growth_config.tres. Idempotent. Edit the patterns here, then rebuild.
## Pattern key: '@' = the heart (identity glyph), '.' = empty, '*' = filler glyph (the identity's body glyphs), other =
## itself. Task-099: the many form is a small human (about 2 x 3 tiles: 7 x 11 cells of small glyphs) that slowly
## morphs into a lion head, an angelic winged body and a hand and back (EntityMorph). Shape ideas (documentation only,
## never loaded): docs/art/forms/many/*.png. Every shape keeps the heart in the same cell so the body glides around it.
## Usage: godot --headless --max-fps 30 --path . -s tools/build_entity_growth.gd

const DIR := "res://resources/config/"
const FORMATION_DIR := "res://resources/config/formations/"
## Cell spacing of the small body glyphs (world units): 7 columns ~ 2 tiles wide, 11 rows ~ 3 tiles tall.
const ADVANCE := Vector2(0.28, 0.27)
## Height of one body glyph (world units).
const BODY_GLYPH_SIZE := 0.42
## Dark backing around each small body glyph (fraction of the glyph tile), so the figure reads as a silhouette on the
## glyph floor.
const BODY_OUTLINE_WIDTH := 0.16
## Cool, bright body colours: the small glyphs must stand out from the warm glyph floor.
const BODY_FILLER_COLOR := Color(0.62, 0.9, 1.0)
const BODY_STRUCTURAL_COLOR := Color(0.95, 1.0, 1.0)

const HUMAN: PackedStringArray = [
	"..***..",
	"..***..",
	"...*...",
	".*****.",
	"*.***.*",
	"*.*@*.*",
	"*.***.*",
	"..***..",
	"..*.*..",
	"..*.*..",
	".**.**.",
]
const LION: PackedStringArray = [
	".\\|||/.",
	"\\*****/",
	"(*o*o*)",
	"|*****|",
	"|**V**|",
	"(**@**)",
	"\\*=w=*/",
	".\\***/.",
	"./*Y*\\.",
	"/.|*|.\\",
	"../.\\..",
]
const ANGEL: PackedStringArray = [
	"\\.***./",
	"\\\\***//",
	".\\\\*//.",
	"\\\\***//",
	".\\*|*/.",
	"..*@*..",
	"..***..",
	"..*|*..",
	"..*.*..",
	"..*.*..",
	"..'.'..",
]
const HAND: PackedStringArray = [
	"..|.|..",
	".||.||.",
	"|||.||.",
	"||||||.",
	"|*****/",
	"|**@**/",
	"|*****.",
	".\\***/.",
	"..***..",
	"..|*|..",
	"..|*|..",
]
## Formations of earlier builds that are no longer used (removed when found).
const OLD: PackedStringArray = ["winged", "beetle", "sprite"]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FORMATION_DIR))
	var ok := true
	var built: Dictionary = {}
	for spec in [[&"human", HUMAN], [&"lion_head", LION], [&"angelic", ANGEL], [&"hand", HAND]]:
		var f := EntityFormation.new()
		f.id = spec[0]
		f.rows = spec[1]
		f.advance = ADVANCE
		var path: String = "%s%s.tres" % [FORMATION_DIR, spec[0]]
		ok = _save(f, path) and ok
		built[spec[0]] = load(path) as EntityFormation
	var config := EntityGrowthConfig.new()
	config.formations = [built[&"human"]] as Array[EntityFormation]
	config.morph_shapes = [built[&"lion_head"], built[&"angelic"], built[&"hand"]] as Array[EntityFormation]
	config.glyph_size = BODY_GLYPH_SIZE
	config.outline_width = BODY_OUTLINE_WIDTH
	config.filler_color = BODY_FILLER_COLOR
	config.structural_color = BODY_STRUCTURAL_COLOR
	ok = _save(config, DIR + "entity_growth_config.tres") and ok
	for id in OLD:
		var old: String = "%s%s.tres" % [FORMATION_DIR, id]
		if FileAccess.file_exists(old):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(old))
			print("Removed ", old)
	quit(0 if ok else 1)


func _save(res: Resource, path: String) -> bool:
	var err: Error = ResourceSaver.save(res, path)
	if err != OK:
		push_error("Could not save %s: %s" % [path, error_string(err)])
		return false
	print("Saved ", path)
	return true
