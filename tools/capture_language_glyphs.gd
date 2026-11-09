extends SceneTree
## Debug capture (TASK-100, not part of the boot path): one narrator line per language at a low understanding, each
## saved as a PNG so the per-language stand-ins (and the Dream font) can be looked at.
##   godot --path . --max-fps 30 --resolution 960x540 -s tools/capture_language_glyphs.gd -- <out_dir>
## Languages from the bundled seed (data/db/seed.json, table language_def).

const CONFIG_PATH := "res://resources/narration/narrator_config.tres"
const SEED_PATH := "res://data/db/seed.json"
const TEXT := "Did you see the wall breathe"
## Understanding per shot: static stand-ins, then spinning ones.
const SHOTS: Array[float] = [0.05, 0.2]
const SETTLE_FRAMES := 45

var _overlay: CanvasLayer
var _rows: Array = []
var _out: String = ""
var _shot: int = 0
var _wait: int = 0


func _init() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_out)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SEED_PATH))
	_rows = (data as Dictionary).get("language_def", [])
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04)
	bg.size = Vector2(4096, 4096)
	root.add_child(bg)
	_overlay = load("res://scripts/narrator/narration_overlay.gd").new()
	_overlay.set("config", load(CONFIG_PATH))
	root.add_child(_overlay)
	_next()
	process_frame.connect(_tick)


func _next() -> void:
	if _shot >= _rows.size() * SHOTS.size():
		quit(0)
		return
	var row: Dictionary = _rows[_shot / SHOTS.size()]
	var beat := NarrationBeat.new()
	beat.text = TEXT
	beat.layer = NarrationBeat.Layer.NARRATOR
	var glyphs := LanguageGlyphs.from_row(row, _overlay.get("config"))
	_overlay.call("show_beat", beat, 0.0, "", SHOTS[_shot % SHOTS.size()], glyphs)
	_wait = SETTLE_FRAMES


func _tick() -> void:
	_wait -= 1
	if _wait > 0:
		return
	var row: Dictionary = _rows[_shot / SHOTS.size()]
	var name: String = "%s_%02d.png" % [row["id"], int(SHOTS[_shot % SHOTS.size()] * 100.0)]
	root.get_texture().get_image().save_png(_out.path_join(name))
	print("SHOT ", name)
	_shot += 1
	_next()
