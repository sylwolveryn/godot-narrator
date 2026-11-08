extends Node
## Developer performance overlay (autoload `PerfOverlay`): FPS, frametime, CPU time and GPU time graphs
## from the vendored Debug Menu addon (addons/debug_menu, Calinou, MIT).
## The god launcher switches it on and off in the running game by writing `user://dev_flags.cfg`
## ([overlay] perf=true|false); this node polls the file's modified time and applies the change.
## The addon scene is only instanced the first time the overlay is switched on, so a game that never
## shows it pays nothing (render-time measuring stays off). Once instanced, F3 also cycles it.

## Flag file written by god (god/core.py DEV_FLAGS_FILE_NAME).
const FLAGS_PATH := "user://dev_flags.cfg"
const FLAGS_SECTION := "overlay"
const FLAGS_KEY := "perf"
const MENU_SCENE := "res://addons/debug_menu/debug_menu.tscn"
const MenuScript := preload("res://addons/debug_menu/debug_menu.gd")

## Seconds between reads of the flag file.
@export var poll_seconds := 0.5

var _menu: CanvasLayer
var _last_text := ""
var _polled_once := false
var _timer: Timer


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_timer = Timer.new()
	_timer.wait_time = poll_seconds
	_timer.timeout.connect(_poll)
	add_child(_timer)
	_timer.start()
	_poll()


func _poll() -> void:
	var text := FileAccess.get_file_as_string(FLAGS_PATH) if FileAccess.file_exists(FLAGS_PATH) else ""
	if _polled_once and text == _last_text:
		return
	_polled_once = true
	_last_text = text
	var cfg := ConfigFile.new()
	if not text.is_empty() and cfg.parse(text) != OK:
		return
	_apply(bool(cfg.get_value(FLAGS_SECTION, FLAGS_KEY, false)))


func _apply(on: bool) -> void:
	if not on and _menu == null:
		return
	if _menu == null:
		_menu = (load(MENU_SCENE) as PackedScene).instantiate() as CanvasLayer
		add_child(_menu)
	_menu.style = MenuScript.Style.VISIBLE_DETAILED if on else MenuScript.Style.HIDDEN
