class_name FountainWhisper
extends Node
## The gargoyle fountain's hidden message (task-092). While the player is within `reach_cells` of a standing fountain,
## once per fountain per run, a narration event is fired that depends on the selected language: `secret_events` maps a
## language to its own event (DREAM reads the message itself), languages in `silent_languages` hear nothing (English
## sees nothing hidden), every other language gets `whisper_event` (a hint that something is hidden).
## Reads the map, the player and the selected language; speaks only through SignalBus.narration_event.

@export var map_loader: MapLoader
@export var player: Node3D
## Read-only: the selected language.
@export var language: LanguageProgress
## Large object type of the fountain (MapLegend large object name).
@export var fountain_type: StringName = &"gargoyle"
## Chebyshev distance in cells from the fountain's footprint that counts as near.
@export var reach_cells: int = 2
@export var silent_languages: PackedStringArray = PackedStringArray(["EN_GB"])
@export var secret_events: Dictionary[StringName, StringName] = {&"DREAM": NarrationEvents.FOUNTAIN_SECRET}
@export var whisper_event: StringName = NarrationEvents.FOUNTAIN_WHISPER

## Fountains already heard this run.
var _done: Dictionary[LargeObjectPlacement, bool] = {}
var _last_cell := Vector2i(-1000000, -1000000)


func _ready() -> void:
	SignalBus.run_started.connect(func(_i: int) -> void:
		_done.clear()
		_last_cell = Vector2i(-1000000, -1000000))


func _physics_process(_delta: float) -> void:
	if map_loader == null or player == null or map_loader.data.is_empty():
		return
	var cell: Vector2i = map_loader.world_to_cell(player.global_position)
	if cell == _last_cell:
		return
	_last_cell = cell
	check(cell)


## Fires the event for the first standing fountain within reach of `cell` not heard this run. Returns the event fired
## (empty when none).
func check(cell: Vector2i) -> StringName:
	for p: LargeObjectPlacement in map_loader.data.large_objects:
		if p.type != fountain_type or p.destroyed or _done.has(p) or not _near(p.rect, cell):
			continue
		_done[p] = true
		var event: StringName = event_for(language.selected_language() if language != null else &"")
		if event != &"":
			SignalBus.narration_event.emit(event)
		return event
	return &""


## The event for a language: its own secret, nothing for a silent language, otherwise the whisper.
func event_for(lang: StringName) -> StringName:
	if secret_events.has(lang):
		return secret_events[lang]
	if silent_languages.has(String(lang)):
		return &""
	return whisper_event


func _near(rect: Rect2i, cell: Vector2i) -> bool:
	var grown: Rect2i = rect.grow(reach_cells)
	return grown.has_point(cell)
