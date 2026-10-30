class_name SaveService
extends Node
## Owns the PersistentProgress resource. In M1 task-007 it lives in memory only.
## Disk IO (user://progress.tres) is added by task-013 behind load_progress()/save_progress().

signal progress_changed

var progress: PersistentProgress = PersistentProgress.new()


func _ready() -> void:
	load_progress()
	SignalBus.run_started.connect(_on_run_started)


## SEAM for task-013: replace the body with a read of user://progress.tres
## (fresh default plus a logged warning when missing or corrupt).
func load_progress() -> void:
	pass


## SEAM for task-013: replace the body with a ResourceSaver write to user://progress.tres.
func save_progress() -> void:
	pass


## Returns the stored identity glyph, picking and storing a random one from `pool` if none exists yet.
func ensure_identity(pool: IdentityPool, rng: RandomNumberGenerator = null) -> String:
	if progress.identity_glyph == "":
		progress.identity_glyph = pool.pick(rng)
		progress_changed.emit()
		save_progress()
	return progress.identity_glyph


func _on_run_started(_run_index: int) -> void:
	progress.run_count += 1
	progress_changed.emit()
	save_progress()
