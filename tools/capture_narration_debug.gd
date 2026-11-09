extends SceneTree
## Visual check of the narration queue debug overlay (task-020.07). Boots main.tscn on a temporary save, shows the
## overlay, fires a burst of narration events so the queue, chain and waiting FIFO fill, and saves screenshots.
##   godot --path . --max-fps 30 --resolution 1280x720 -s tools/capture_narration_debug.gd -- <out_dir>
## Not part of the normal boot path.

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "capture_narration_debug"

## Frame -> action: "ev:<EVENT>" fires SignalBus.narration_event, "shot:<name>" saves a PNG, "quit".
var _schedule: Dictionary = {
	150: "ev:WALL_REVEALED",
	151: "ev:DIAMOND_FOUND",
	152: "ev:SPIKES_REVEALED",
	160: "ev:ENEMY_DESTROYED",
	200: "shot:queue_a",
	300: "shot:queue_b",
	420: "shot:queue_c",
	421: "quit",
}
var _frame: int = 0
var _out: String = "user://"


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	Support.isolate_save(main, SAVE_TAG)
	root.add_child(main)
	var overlay: CanvasLayer = (load("res://scripts/ui/narration_debug_overlay.gd") as GDScript).new()
	root.add_child(overlay)
	overlay.set_active(true)
	process_frame.connect(_tick)


func _tick() -> void:
	_frame += 1
	if not _schedule.has(_frame):
		return
	var action: String = _schedule[_frame]
	if action.begins_with("ev:"):
		root.get_node("SignalBus").emit_signal("narration_event", StringName(action.substr(3)))
	elif action.begins_with("shot:"):
		var path: String = _out.path_join(action.substr(5) + ".png")
		root.get_texture().get_image().save_png(path)
		print("SHOT ", path)
	elif action == "quit":
		quit()
