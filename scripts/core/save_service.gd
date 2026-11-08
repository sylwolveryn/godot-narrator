class_name SaveService
extends Node
## Owns the PersistentProgress resource and its file (SaveConfig.save_path).
## Loads at startup (before any run), saves whenever a run ends. A missing or corrupt file
## falls back to fresh progress with a warning; loading never executes scripts from the file.

signal progress_changed
## Emitted after a progress file was loaded and sanitized (not for the fresh fallback). Lets data owners repair semantic invariants.
signal progress_loaded

@export var config: SaveConfig

var progress: PersistentProgress = PersistentProgress.new()

## True when progress changed since the last write; used to save on quit without needless writes.
var _dirty: bool = false

## Header tags a progress file may contain. Embedded sub-resources (e.g. scripts) are never allowed.
const _ALLOWED_TAGS: PackedStringArray = ["gd_resource", "ext_resource", "resource"]


func _ready() -> void:
	if config == null:
		config = SaveConfig.new()
	load_progress()
	SignalBus.run_started.connect(_on_run_started)
	SignalBus.run_ended.connect(_on_run_ended)
	SignalBus.cells_revealed.connect(_on_cells_revealed)
	SignalBus.beat_heard.connect(_on_beat_heard)


## Reads the progress file. Missing, corrupt or foreign files give fresh progress and a warning.
func load_progress() -> void:
	if config == null:
		config = SaveConfig.new()
	var path: String = config.save_path
	progress = PersistentProgress.new()
	if not FileAccess.file_exists(path):
		push_warning("[SaveService] No save at %s, starting fresh" % path)
		return
	var text: String = FileAccess.get_file_as_string(path)
	if not _is_safe_text(text):
		push_warning("[SaveService] Save at %s is corrupt or not a progress file, starting fresh" % path)
		return
	var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not loaded is PersistentProgress:
		push_warning("[SaveService] Save at %s did not load as PersistentProgress, starting fresh" % path)
		return
	progress = _sanitized(loaded as PersistentProgress)
	progress_loaded.emit()
	progress_changed.emit()


## Writes the progress atomically (temp file, then rename). Failures are logged, never fatal.
func save_progress() -> void:
	var path: String = config.save_path
	var temp: String = path.get_basename() + ".tmp." + path.get_extension()
	var err: Error = ResourceSaver.save(progress, temp)
	if err != OK:
		push_warning("[SaveService] Could not write %s: %s" % [temp, error_string(err)])
		return
	err = DirAccess.rename_absolute(temp, path)
	if err != OK:
		push_warning("[SaveService] Could not move %s to %s: %s" % [temp, path, error_string(err)])
		DirAccess.remove_absolute(temp)
		return
	_dirty = false


## Saves on quit so mid-run reveals and heard beats survive closing the game.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_if_dirty()


func _exit_tree() -> void:
	save_if_dirty()


## Marks progress changed by its owner (e.g. OriginLedger), notifies listeners and saves at once.
func commit_progress() -> void:
	_dirty = true
	progress_changed.emit()
	save_progress()


## Marks progress changed by its owner without writing at once (frequent small changes, e.g. the language step
## counter); the next save (run end, quit or a commit) writes it.
func mark_dirty() -> void:
	_dirty = true
	progress_changed.emit()


## Writes the progress only when something changed since the last write.
func save_if_dirty() -> void:
	if _dirty and config != null:
		save_progress()


## Returns the stored identity glyph, picking and storing a random one from `pool` if none exists yet.
func ensure_identity(pool: IdentityPool, rng: RandomNumberGenerator = null) -> String:
	if progress.identity_glyph == "":
		progress.identity_glyph = pool.pick(rng)
		progress_changed.emit()
		save_progress()
	return progress.identity_glyph


## Cells remembered for a map, as grid coordinates. Empty when the map was never seen.
func get_revealed_cells(map_id: StringName) -> PackedVector2Array:
	return progress.revealed_cells.get(map_id, PackedVector2Array())


## Records that the multi-glyph entity is unlocked (stays unlocked) and saves at once.
func unlock_entity() -> void:
	if progress.entity_unlocked:
		return
	progress.entity_unlocked = true
	_dirty = true
	progress_changed.emit()
	save_progress()


## Records that the in-world menu is unlocked (stays unlocked) and saves at once.
func unlock_menu() -> void:
	if progress.menu_unlocked:
		return
	progress.menu_unlocked = true
	_dirty = true
	progress_changed.emit()
	save_progress()


## Stores the active entity form (EntityForm names). Ignored for an unknown form or before the unlock.
func set_entity_form(form: StringName) -> void:
	if not progress.entity_unlocked or not EntityForm.is_valid(form) or progress.entity_form == String(form):
		return
	progress.entity_form = String(form)
	_dirty = true
	progress_changed.emit()
	save_progress()


## Records that the grow moment has played.
func mark_entity_grow_played() -> void:
	if progress.entity_grow_played:
		return
	progress.entity_grow_played = true
	_dirty = true
	progress_changed.emit()
	save_progress()


func _on_cells_revealed(map_id: StringName, cells: PackedVector2Array) -> void:
	var known: PackedVector2Array = get_revealed_cells(map_id)
	known.append_array(cells)
	progress.revealed_cells[map_id] = known
	_dirty = true
	progress_changed.emit()


func _on_beat_heard(beat_id: String) -> void:
	if progress.heard_beats.has(beat_id):
		return
	progress.heard_beats.append(beat_id)
	_dirty = true
	progress_changed.emit()


func _on_run_started(_run_index: int) -> void:
	progress.run_count += 1
	_dirty = true
	progress_changed.emit()


func _on_run_ended(_cause: StringName) -> void:
	progress.death_count += 1
	_dirty = true
	progress_changed.emit()
	save_progress()


## True when the text is a text resource whose only references are the allowed progress scripts.
func _is_safe_text(text: String) -> bool:
	if not text.begins_with("[gd_resource"):
		return false
	var tag := RegEx.create_from_string("(?m)^\\[(\\w+)([^\\]\\n]*)\\]")
	var resource_tags: int = 0
	for m in tag.search_all(text):
		var tag_name: String = m.get_string(1)
		if not _ALLOWED_TAGS.has(tag_name):
			return false
		if tag_name == "resource":
			resource_tags += 1
		elif tag_name == "ext_resource" and not _is_allowed_reference(m.get_string(2)):
			return false
	return resource_tags == 1


func _is_allowed_reference(attributes: String) -> bool:
	var path := RegEx.create_from_string("path=\"([^\"]*)\"").search(attributes)
	return path != null and config.allowed_script_paths.has(path.get_string(1))


## Copy of loaded data restricted to well-typed persistent values.
func _sanitized(loaded: PersistentProgress) -> PersistentProgress:
	var clean := PersistentProgress.new()
	clean.identity_glyph = loaded.identity_glyph.substr(0, config.max_identity_length)
	clean.run_count = maxi(0, loaded.run_count)
	clean.death_count = maxi(0, loaded.death_count)
	clean.heard_beats = loaded.heard_beats
	clean.entity_unlocked = loaded.entity_unlocked
	clean.entity_form = loaded.entity_form if EntityForm.is_valid(StringName(loaded.entity_form)) else String(EntityForm.SINGLE)
	clean.entity_grow_played = loaded.entity_grow_played and loaded.entity_unlocked
	clean.menu_unlocked = loaded.menu_unlocked
	# Origin ledger: only types and duplicates are fixed here; OriginLedger drops unknown ids and repairs the invariant.
	clean.struck_natures = _unique(loaded.struck_natures)
	clean.armed_trials = _unique(loaded.armed_trials)
	clean.last_strike_run = maxi(0, loaded.last_strike_run)
	for key: Variant in loaded.strike_counts:
		var count: Variant = loaded.strike_counts[key]
		if (key is StringName or key is String) and count is int:
			clean.strike_counts[String(key)] = maxi(0, count)
	# Language (task-065): only types are fixed here; LanguageProgress clamps, drops unknown ids and fills defaults.
	for key: Variant in loaded.language_understanding:
		var percent: Variant = loaded.language_understanding[key]
		if (key is StringName or key is String) and (percent is float or percent is int):
			clean.language_understanding[String(key)] = float(percent)
	clean.selected_language = loaded.selected_language
	clean.unlocked_languages = _unique(loaded.unlocked_languages)
	clean.discovered_types = _unique(loaded.discovered_types)
	clean.language_step_remainder = maxi(0, loaded.language_step_remainder)
	for key: Variant in loaded.revealed_cells:
		var cells: Variant = loaded.revealed_cells[key]
		if (key is StringName or key is String) and cells is PackedVector2Array:
			clean.revealed_cells[StringName(key)] = cells
	return clean


## Copy without duplicates, order kept.
func _unique(values: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for v in values:
		if not out.has(v):
			out.append(v)
	return out
