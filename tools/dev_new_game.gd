extends SceneTree
## Dev tool (task-078): writes a NEW game's save with mods, before god starts the game. Uses the game's own SaveService,
## so the file is a normal progress file; everything not modded is a fresh game (no runs, no deaths, no identity).
## Mods (all optional, user arguments after `--`):
##   --language=<percent>   every language unlocked at this understanding (the start language stays selected)
##   --dirt=<count>         consumed dirt (PersistentProgress.consumed) to start with
##   --diamonds=<count>     diamonds collected (consumed and PersistentProgress.diamonds) to start with
##   --save=<path>          write here instead of the save from resources/config/save_config.tres (tests)
## Usage: godot --headless --path . -s tools/dev_new_game.gd -- --language=80 --dirt=10000 --diamonds=10000

const SAVE_CONFIG_PATH := "res://resources/config/save_config.tres"
const LANGUAGE_CONFIG_PATH := "res://resources/config/language_config.tres"


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _fail(msg: String) -> void:
	printerr("FAIL dev_new_game: ", msg)
	quit(1)


func _run() -> void:
	var cfg: SaveConfig = (load(SAVE_CONFIG_PATH) as SaveConfig).duplicate()
	var args: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.substr(2).split("=", true, 1)
			args[parts[0]] = parts[1]
	if args.has("save"):
		cfg.save_path = str(args["save"])
	var progress := PersistentProgress.new()
	var applied := PackedStringArray()

	if args.has("language"):
		var pct: float = float(args["language"])
		if pct < 0.0:
			_fail("language percent must be >= 0")
			return
		var lang: LanguageConfig = load(LANGUAGE_CONFIG_PATH) as LanguageConfig
		var all: PackedStringArray = lang.all_languages()
		var value: float = clampf(pct, 0.0, lang.max_percent)
		progress.unlocked_languages = all
		progress.selected_language = String(lang.start_language)
		for id in all:
			progress.language_understanding[id] = value
		applied.append("%d languages at %s%%" % [all.size(), value])
	for pair in [["dirt", Consumable.DIRT], ["diamonds", Consumable.DIAMOND]]:
		if not args.has(pair[0]):
			continue
		var count: int = int(args[pair[0]])
		if count < 0:
			_fail("%s must be >= 0" % pair[0])
			return
		progress.consumed[String(pair[1])] = count
		if pair[1] == Consumable.DIAMOND:
			progress.diamonds = count
		applied.append("%d %s" % [count, pair[0]])

	var svc: Node = load("res://scripts/core/save_service.gd").new()
	svc.set("config", cfg)
	svc.set("progress", progress)
	svc.call("save_progress")
	svc.free()
	if not FileAccess.file_exists(cfg.save_path):
		_fail("could not write %s" % cfg.save_path)
		return
	print("PASS dev_new_game: %s in %s" % [", ".join(applied) if not applied.is_empty() else "no mods", cfg.save_path])
	quit(0)
