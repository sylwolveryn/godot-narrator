class_name LanguageProgress
extends Node
## Data layer of language understanding (task-065), the game's core progress meter. The ONLY writer of the language
## fields of PersistentProgress (through SaveService) and of the DB player_language rows (GameDatabase reducer
## set_language_understanding). Gains go to the SELECTED language, clamped to LanguageConfig.max_percent:
## walking (SignalBus.player_stepped), every run end (a death) and the first discovery ever of a cell type
## (SignalBus.cells_revealed). The Language menu (MenuController) asks for the list (language_list_requested: may
## unlock the next language and start a glyph storm) and for a selection (language_select_requested).
## Speaks through SignalBus: language_understanding_changed / language_selected / language_unlocked.
## Sits right after SaveService and before the Narrator so its run-start announcement comes first.
## Top limit (task-077): the DB column player_language.max (>= 0) caps a language below LanguageConfig.max_percent;
## a value already over it is brought down to it at once (saved and mirrored). -1 / missing = no extra limit.
## Live god edits (task-078): on a DB reload after the startup read (GameDatabase.server_loads > 1, i.e. the god tool
## bumped config_version), an understanding in player_language that this game never sent is a god edit: it is adopted
## for an unlocked language (clamped to the cap), saved and announced. Values the game sent itself (also stale ones
## still on their way) are ignored.

@export var config: LanguageConfig
@export var save_service: SaveService
## Read-only: cell types of revealed cells.
@export var map_loader: MapLoader
## Mirror of the understanding (DB player_language). Optional.
@export var database: GameDatabase
## Read-only: centre of the unlock storm.
@export var player: Node3D

const REDUCER: String = "set_language_understanding"
const LANGUAGE_TABLE: String = "player_language"
const MAX_COLUMN: String = "max"

## Repeat gains (task-087); tests seed it.
var rng := RandomNumberGenerator.new()
## Language id -> whole percent last sent to the DB.
var _pushed: Dictionary = {}
## Language id (String) -> top limit in percent from the DB (only languages with a limit set).
var _limits: Dictionary = {}
## Language id (String) -> every understanding value sent to the DB this session (to tell god's edits from echoes).
var _sent: Dictionary = {}
## Two percents closer than this are the same value (the DB stores f32).
const SAME_PERCENT: float = 0.01


func _ready() -> void:
	if config == null:
		config = LanguageConfig.new()
	if save_service == null:
		return
	save_service.progress_loaded.connect(_on_progress_loaded)
	SignalBus.run_started.connect(_on_run_started)
	SignalBus.run_ended.connect(_on_run_ended)
	SignalBus.player_stepped.connect(_on_player_stepped)
	SignalBus.cells_revealed.connect(_on_cells_revealed)
	SignalBus.language_list_requested.connect(_on_list_requested)
	SignalBus.language_select_requested.connect(select)
	SignalBus.beat_repeated.connect(_on_beat_repeated)
	if database != null:
		database.tables_loaded.connect(_on_tables_loaded)
		_read_limits(database.tables)
	repair()
	# Listeners further down the tree connect in their own _ready: announce once everything is ready.
	announce.call_deferred(true)


## The selected (narration) language.
func selected_language() -> StringName:
	return StringName(_progress().selected_language)


## Understanding of a language in percent (0 when locked or unknown).
func percent(language: StringName) -> float:
	return float(_progress().language_understanding.get(String(language), 0.0))


## Highest understanding a language may reach: LanguageConfig.max_percent, or the DB top limit when that is lower.
func cap(language: StringName) -> float:
	var top: float = config.max_percent
	var key: String = String(language)
	if _limits.has(key):
		top = minf(top, float(_limits[key]))
	return maxf(top, 0.0)


## Understanding of the selected language as 0..1 (of max_percent).
func understanding() -> float:
	return _ratio(percent(selected_language()))


## Unlocked language ids, in unlock order (the start language first).
func unlocked_languages() -> PackedStringArray:
	return _progress().unlocked_languages


func is_unlocked(language: StringName) -> bool:
	return _progress().unlocked_languages.has(String(language))


## The next language the Language menu would unlock; empty when every language is unlocked.
func next_locked_language() -> StringName:
	for id in config.unlock_order:
		if not is_unlocked(StringName(id)):
			return StringName(id)
	return &""


## One Language menu entry per unlocked language: "English 37%" (whole percents).
func entry_labels() -> PackedStringArray:
	var out := PackedStringArray()
	for id in unlocked_languages():
		out.append(config.entry_format % [config.display_name(StringName(id)), floori(percent(StringName(id)))])
	return out


## Fills the defaults of a new save and repairs a loaded one (unknown ids dropped, values clamped, the start language
## always unlocked, a valid selection). Saves only when something changed.
func repair() -> void:
	if save_service == null:
		return
	var p: PersistentProgress = _progress()
	var known: PackedStringArray = config.all_languages()
	var changed: bool = false
	var unlocked := PackedStringArray([String(config.start_language)])
	for id in p.unlocked_languages:
		if known.has(id) and not unlocked.has(id):
			unlocked.append(id)
	if unlocked != p.unlocked_languages:
		p.unlocked_languages = unlocked
		changed = true
	var values: Dictionary = {}
	for id in unlocked:
		var start: float = config.start_percent if id == String(config.start_language) else config.unlocked_start_percent
		values[id] = clampf(float(p.language_understanding.get(id, start)), 0.0, cap(StringName(id)))
	if values != p.language_understanding:
		p.language_understanding = values
		changed = true
	if not unlocked.has(p.selected_language):
		p.selected_language = String(config.start_language)
		changed = true
	var quota: int = maxi(1, config.tiles_per_percent)
	if p.language_step_remainder >= quota:
		p.language_step_remainder = p.language_step_remainder % quota
		changed = true
	if changed:
		save_service.commit_progress()


## Announces the selection and its understanding to the listeners; `push_db` also mirrors every language to the DB.
func announce(push_db: bool = false) -> void:
	if save_service == null:
		return
	var language: StringName = selected_language()
	SignalBus.language_selected.emit(language)
	SignalBus.language_understanding_changed.emit(language, understanding())
	if push_db:
		for id in config.all_languages():
			_push(StringName(id), true)


## Adds `amount` percent to the selected language (clamped). Returns true when the value changed.
func add_percent(amount: float) -> bool:
	var language: StringName = selected_language()
	var before: float = percent(language)
	var after: float = clampf(before + amount, 0.0, cap(language))
	if is_equal_approx(before, after):
		return false
	_progress().language_understanding[String(language)] = after
	if floori(before) != floori(after):
		save_service.commit_progress()
		_push(language, false)
	else:
		save_service.mark_dirty()
	SignalBus.language_understanding_changed.emit(language, _ratio(after))
	return true


## Selects an unlocked language (the Language menu asks through SignalBus.language_select_requested).
func select(language: StringName) -> bool:
	if save_service == null or not is_unlocked(language):
		return false
	if language == selected_language():
		return true
	_progress().selected_language = String(language)
	save_service.commit_progress()
	announce(false)
	return true


## Unlocks the next language at unlocked_start_percent when the selected one has reached unlock_at_percent, and starts
## the glyph storm around the player. At most one unlock per call. Returns the unlocked id, empty when none.
func try_unlock() -> StringName:
	if save_service == null or percent(selected_language()) < config.unlock_at_percent:
		return &""
	var next: StringName = next_locked_language()
	if next == &"":
		return &""
	var p: PersistentProgress = _progress()
	p.unlocked_languages.append(String(next))
	p.language_understanding[String(next)] = clampf(config.unlocked_start_percent, 0.0, cap(next))
	save_service.commit_progress()
	_push(next, true)
	SignalBus.language_unlocked.emit(next)
	var centre: Vector3 = player.global_position if player != null and player.is_inside_tree() else Vector3.ZERO
	SignalBus.glyph_storm_requested.emit(centre, config.unlock_storm_radius, config.unlock_storm_duration, config.unlock_storm_tint)
	return next


func _progress() -> PersistentProgress:
	return save_service.progress


func _ratio(value: float) -> float:
	return clampf(value / config.max_percent, 0.0, 1.0) if config.max_percent > 0.0 else 0.0


## Mirrors one language to the DB when its whole percent changed since the last call (or always with `force`).
func _push(language: StringName, force: bool) -> void:
	if database == null:
		return
	var value: float = percent(language)
	var whole: int = floori(value)
	if not force and _pushed.get(language, -1) == whole:
		return
	_pushed[language] = whole
	_remember_sent(String(language), value)
	database.call_reducer(REDUCER, [String(language), value])


## The cell type that counts as a discovery for a revealed cell (empty = never counts).
func _discovery_type(cell: Vector2i) -> StringName:
	var data: MapData = map_loader.data
	var type: StringName = data.type_at(cell)
	if type == MapLegend.SPAWN:
		type = MapLegend.FLOOR
	if type == MapLegend.FLOOR and data.objects.has(cell):
		type = MapLegend.OBJECT
	if config.ignored_types.has(String(type)):
		return &""
	return type


## The DB tables arrived (seed, server or reload): take the top limits and bring values over them down.
func _on_tables_loaded(tables: Dictionary) -> void:
	_read_limits(tables)
	apply_limits()
	if database != null and database.online and database.server_loads > 1:
		adopt_db_values(tables)


## Takes understanding values the god tool wrote into player_language (see the class notes). Returns the adopted ids.
func adopt_db_values(tables: Dictionary) -> PackedStringArray:
	var adopted := PackedStringArray()
	if save_service == null:
		return adopted
	var values: Dictionary = _progress().language_understanding
	for row in tables.get(LANGUAGE_TABLE, []):
		if not row is Dictionary:
			continue
		var id: String = str(row.get("language", ""))
		if not is_unlocked(StringName(id)) or not row.has("understanding"):
			continue
		var value: float = clampf(float(row["understanding"]), 0.0, cap(StringName(id)))
		if absf(value - float(values.get(id, 0.0))) < SAME_PERCENT or _was_sent(id, value):
			continue
		values[id] = value
		_remember_sent(id, value)
		_pushed[StringName(id)] = floori(value)
		adopted.append(id)
	if adopted.is_empty():
		return adopted
	save_service.commit_progress()
	SignalBus.language_understanding_changed.emit(selected_language(), understanding())
	return adopted


func _was_sent(id: String, value: float) -> bool:
	for v: float in _sent.get(id, []):
		if absf(v - value) < SAME_PERCENT:
			return true
	return false


func _remember_sent(id: String, value: float) -> void:
	if not _sent.has(id):
		_sent[id] = []
	(_sent[id] as Array).append(value)


func _read_limits(tables: Dictionary) -> void:
	_limits.clear()
	for row in tables.get(LANGUAGE_TABLE, []):
		if not row is Dictionary or not row.has(MAX_COLUMN):
			continue
		var top: float = float(row[MAX_COLUMN])
		if top >= 0.0:
			_limits[String(row.get("language", ""))] = top


## Brings every language over its top limit down to it (saved and mirrored to the DB). Returns true when any changed.
func apply_limits() -> bool:
	if save_service == null:
		return false
	var values: Dictionary = _progress().language_understanding
	var lowered: Array[StringName] = []
	for id in values.keys():
		var top: float = cap(StringName(id))
		if float(values[id]) > top:
			values[id] = top
			lowered.append(StringName(id))
	if lowered.is_empty():
		return false
	save_service.commit_progress()
	for id in lowered:
		_push(id, true)
	SignalBus.language_understanding_changed.emit(selected_language(), understanding())
	return true


func _on_progress_loaded() -> void:
	repair()
	announce(true)


func _on_run_started(_run_index: int) -> void:
	announce(false)


func _on_run_ended(_cause: StringName) -> void:
	add_percent(config.percent_per_death)


func _on_player_stepped(_cell: Vector2i) -> void:
	var p: PersistentProgress = _progress()
	p.language_step_remainder += 1
	if p.language_step_remainder >= maxi(1, config.tiles_per_percent):
		p.language_step_remainder = 0
		if add_percent(config.percent_per_steps):
			return
	save_service.mark_dirty()


func _on_cells_revealed(_map_id: StringName, cells: PackedVector2Array) -> void:
	if map_loader == null or map_loader.data == null:
		return
	var p: PersistentProgress = _progress()
	for c in cells:
		var type: StringName = _discovery_type(Vector2i(c))
		if type == &"" or p.discovered_types.has(String(type)):
			continue
		p.discovered_types.append(String(type))
		if not add_percent(config.percent_per_new_type):
			save_service.commit_progress()


## A narration line heard again (task-087): a random repeat_percent_min..max percent for the selected language.
func _on_beat_repeated(_beat_id: String) -> void:
	add_percent(float(rng.randi_range(config.repeat_percent_min, maxi(config.repeat_percent_max, config.repeat_percent_min))))


func _on_list_requested() -> void:
	try_unlock()
