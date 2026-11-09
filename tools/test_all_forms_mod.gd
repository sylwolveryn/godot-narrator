extends SceneTree
## Headless test of god's All forms mod (task-097): tools/dev_new_game.gd --all_forms=1 writes a fresh save with the
## many (grown) and brain forms and the menu unlocked; the main scene started on that save lets every form be chosen.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_all_forms_mod.gd

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "all_forms_mod"
const PHASE_PLAYING := 1

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var save_path: String = Support.isolate_save(main, SAVE_TAG)
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--max-fps", "30", "--path",
			ProjectSettings.globalize_path("res://"), "-s", "tools/dev_new_game.gd", "--", "--all_forms=1",
			"--save=%s" % save_path]), output, true)
	_check(code == 0, "dev_new_game exit code %d: %s" % [code, "\n".join(output)])
	var progress: PersistentProgress = ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PersistentProgress
	_check(progress != null, "the tool wrote a save")
	if progress != null:
		_check(progress.entity_unlocked and progress.brain_unlocked and progress.menu_unlocked, "grown, brain and menu unlocked")
		_check(progress.death_count == 0 and progress.run_count == 0, "otherwise a fresh game")

	var intro: IntroConfig = IntroConfig.new()
	intro.black_hold = 0.05
	intro.wave_fade_in = 0.05
	intro.wave_hold = 0.05
	intro.reveal_duration = 0.05
	main.get_node("IntroSequence").set("config", intro)
	root.add_child(main)
	await create_timer(2.5).timeout
	_check(main.get_node("RunManager").get("phase") == PHASE_PLAYING, "run should be playing")
	var entity: Node = main.get_node("EntityProgression")
	_check(entity.call("is_unlocked") and entity.call("is_brain_unlocked"), "the game sees every form unlocked")
	_check(main.get_node("MenuController").call("is_unlocked"), "the menu that switches forms is open to use")
	_check(entity.call("set_form", EntityForm.BRAIN), "brain form can be chosen")
	_check(entity.call("set_form", EntityForm.SINGLE), "single form can be chosen")

	main.queue_free()
	await process_frame
	Support.remove_file(save_path)
	if _failures.is_empty():
		print("PASS test_all_forms_mod")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_all_forms_mod")
		quit(1)
