class_name SaveService
extends Node
## Owns the PersistentProgress resource and its file (SaveConfig.save_path).
## Loads at startup (before any run), saves whenever a run ends. A missing or corrupt file
## falls back to fresh progress with a warning; loading never executes scripts from the file.

signal progress_changed

@export var config: SaveConfig

var progress: PersistentProgress = PersistentProgress.new()

## Header tags a progress file may contain. Embedded sub-resources (e.g. scripts) are never allowed.
const _ALLOWED_TAGS: PackedStringArray = ["gd_resource", "ext_resource", "resource"]


func _ready() -> void:
	if config == null:
		config = SaveConfig.new()
	load_progress()
	SignalBus.run_started.connect(_on_run_started)
	SignalBus.run_ended.connect(_on_run_ended)
	SignalBus.cells_revealed.connect(_on_cells_revealed)


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


func _on_cells_revealed(map_id: StringName, cells: PackedVector2Array) -> void:
	var known: PackedVector2Array = get_revealed_cells(map_id)
	known.append_array(cells)
	progress.revealed_cells[map_id] = known
	progress_changed.emit()


func _on_run_started(_run_index: int) -> void:
	progress.run_count += 1
	progress_changed.emit()


func _on_run_ended(_cause: StringName) -> void:
	progress.death_count += 1
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
	for key: Variant in loaded.revealed_cells:
		var cells: Variant = loaded.revealed_cells[key]
		if (key is StringName or key is String) and cells is PackedVector2Array:
			clean.revealed_cells[StringName(key)] = cells
	return clean
