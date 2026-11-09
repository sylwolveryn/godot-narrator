extends Node
## Developer bridge (autoload `DevBridge`): the god launcher controls a running game through `user://dev_flags.cfg`,
## which this node re-reads on a timer (a few hundred bytes, cheap).
##   [overlay] perf=true|false   FPS / frametime / CPU / GPU graphs from the vendored Debug Menu addon
##                               (addons/debug_menu, Calinou, MIT). The addon scene is only instanced the first time
##                               it is switched on, so a game that never shows it pays nothing. Once shown, F3 cycles it.
##   [overlay] narration=true|false   narration queue / text / audio debug overlay on the left (NarrationDebugOverlay,
##                               task-020.07); instanced the first time it is switched on.
##   [commands] reveal_map=<n>   a request counter: each new value asks the current map to reveal itself
##                               (SignalBus.dev_reveal_map_requested; MapReveal answers). The value present when the game
##                               starts is only remembered, so an old request never fires again.
## Does nothing in headless runs.

const OVERLAY_SECTION := "overlay"
const PERF_KEY := "perf"
const NARRATION_KEY := "narration"
const COMMANDS_SECTION := "commands"
const REVEAL_KEY := "reveal_map"
const MENU_SCENE := "res://addons/debug_menu/debug_menu.tscn"
const MenuScript := preload("res://addons/debug_menu/debug_menu.gd")

## Flag file written by god (god/core.py DEV_FLAGS_FILE_NAME). Tests point it elsewhere.
@export var flags_path := "user://dev_flags.cfg"
## Seconds between reads of the flag file.
@export var poll_seconds := 0.5

var _menu: CanvasLayer
var _narration: NarrationDebugOverlay
var _last_text := ""
var _polled_once := false
var _reveal_request := 0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var timer := Timer.new()
	timer.wait_time = poll_seconds
	timer.timeout.connect(_poll)
	add_child(timer)
	timer.start()
	_poll()


func _poll() -> void:
	var text := FileAccess.get_file_as_string(flags_path) if FileAccess.file_exists(flags_path) else ""
	if _polled_once and text == _last_text:
		return
	var first := not _polled_once
	_polled_once = true
	_last_text = text
	var cfg := ConfigFile.new()
	if not text.is_empty() and cfg.parse(text) != OK:
		return
	_apply_overlay(bool(cfg.get_value(OVERLAY_SECTION, PERF_KEY, false)))
	_apply_narration(bool(cfg.get_value(OVERLAY_SECTION, NARRATION_KEY, false)))
	var request := int(cfg.get_value(COMMANDS_SECTION, REVEAL_KEY, 0))
	if request != _reveal_request:
		_reveal_request = request
		if not first:
			SignalBus.dev_reveal_map_requested.emit()


func _apply_overlay(on: bool) -> void:
	if not on and _menu == null:
		return
	if _menu == null:
		_menu = (load(MENU_SCENE) as PackedScene).instantiate() as CanvasLayer
		add_child(_menu)
	var style: int = MenuScript.Style.VISIBLE_DETAILED if on else MenuScript.Style.HIDDEN
	if _menu.style != style:
		_menu.style = style


func _apply_narration(on: bool) -> void:
	if not on and _narration == null:
		return
	if _narration == null:
		_narration = NarrationDebugOverlay.new()
		_narration.name = "NarrationDebugOverlay"
		add_child(_narration)
	_narration.set_active(on)
