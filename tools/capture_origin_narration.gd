extends SceneTree
## Visual check of the origin narration (task-042): a claim is heard, two natures are struck (broken lines), then an
## ordinary line whose only supported nature is struck plays as a doubt line. Uses a temporary save file (never the
## player's save): the progress is seeded past the menu threshold (run 5, 4 deaths) and every ordinary beat is marked
## heard, so only the lines of this check can play. Prints "EVENT ... frame <n>" lines.
##   godot --path . --resolution 960x540 --fixed-fps 30 --max-fps 30 --quit-after 960 --write-movie <dir>/f.png -s tools/capture_origin_narration.gd

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "capture_origin_narration"
const SEED_RUNS := 4
const SEED_DEATHS := 4
## Frame of each scripted step (the run is up by then; each line takes about 170 frames plus dissolve and gap).
const FRAME_CLAIM := 40
const FRAME_STRIKE_DEMONIC := 60
const FRAME_STRIKE_AI := 250
const FRAME_DOUBT_TRIGGER := 640
const FRAME_QUIT := 940

var _frame: int = 0
var _main: Node


func _init() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	Support.isolate_save(_main, SAVE_TAG)
	var intro := IntroConfig.new()
	intro.black_hold = 0.2
	intro.wave_fade_in = 0.2
	intro.wave_hold = 0.2
	intro.reveal_duration = 0.4
	_main.get_node("IntroSequence").set("config", intro)
	root.add_child(_main)
	var progress: PersistentProgress = _main.get_node("SaveService").get("progress")
	progress.run_count = SEED_RUNS
	progress.death_count = SEED_DEATHS
	for beat: NarrationBeat in (_main.get_node("Narrator").get("config") as NarratorConfig).beats:
		if beat.role == NarrationBeat.Role.STORY and beat.id != "erosion_again":
			progress.heard_beats.append(beat.id)
	var narrator: Node = _main.get_node("Narrator")
	narrator.connect("beat_started", func(b: NarrationBeat) -> void: print("EVENT beat_started %s doubt=%s frame %d" % [b.id, narrator.get("current_doubt"), _frame]))
	root.get_node("SignalBus").connect("run_started", func(i: int) -> void: print("EVENT run_started %d frame %d" % [i, _frame]))
	process_frame.connect(_tick)


func _tick() -> void:
	_frame += 1
	var bus: Node = root.get_node("SignalBus")
	var ledger: Node = _main.get_node("OriginLedger")
	var run: int = _main.get_node("SaveService").get("progress").run_count
	match _frame:
		FRAME_CLAIM:
			bus.emit_signal("narration_event", &"corruption_entered")
		FRAME_STRIKE_DEMONIC:
			ledger.call("strike", &"demonic", run)
		FRAME_STRIKE_AI:
			ledger.call("strike", &"ai", run)
		FRAME_DOUBT_TRIGGER:
			bus.emit_signal("narration_event", &"erosion_high")
		FRAME_QUIT:
			print("EVENT struck %s armed %s" % [ledger.call("struck_natures"), _main.get_node("SaveService").get("progress").armed_trials])
			Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
			process_frame.disconnect(_tick)
			_main.queue_free()
			await process_frame
			Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
			quit()
