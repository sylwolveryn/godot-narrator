class_name Destructibles
extends Node
## Registry of destructible things (task-073), queried by map cell. It owns no state: every kind of destructible thing
## keeps its own owner (the only writer of its state), which opts in by registering two callables under a kind name:
##   register(kind, is_at: Callable(cell: Vector2i) -> bool, destroy: Callable(cell: Vector2i, cause: StringName) -> bool)
## Owners today: DirtWalls (kind "dirt"), LargeObjects (one kind per destructible large object type, e.g. "gargoyle"),
## TeleportSystem (kind "teleport"). A future owner (TASK-075 enemies: their system knows which cell each enemy is in)
## registers the same way in its _ready; nothing here changes.
## Contract for an owner's `destroy`: return true when something was destroyed, and emit
## SignalBus.destructible_destroyed(kind, rect, world_position, cause) for it (remains and effects hook in there).
## Hitters (cannon balls, later anything else) only call kind_at() / destroy_at().

var _kinds: Array[StringName] = []
var _is_at: Array[Callable] = []
var _destroy: Array[Callable] = []


## Adds (or replaces) the owner of a kind.
func register(kind: StringName, is_at: Callable, destroy: Callable) -> void:
	var i: int = _kinds.find(kind)
	if i >= 0:
		_is_at[i] = is_at
		_destroy[i] = destroy
		return
	_kinds.append(kind)
	_is_at.append(is_at)
	_destroy.append(destroy)


func unregister(kind: StringName) -> void:
	var i: int = _kinds.find(kind)
	if i < 0:
		return
	_kinds.remove_at(i)
	_is_at.remove_at(i)
	_destroy.remove_at(i)


## Registered kinds, in registration order.
func kinds() -> Array[StringName]:
	return _kinds.duplicate()


## The kind of the destructible thing in `cell`, &"" when there is none.
func kind_at(cell: Vector2i) -> StringName:
	for i in _kinds.size():
		if _is_at[i].is_valid() and bool(_is_at[i].call(cell)):
			return _kinds[i]
	return &""


func is_destructible(cell: Vector2i) -> bool:
	return kind_at(cell) != &""


## Destroys the thing in `cell` through its owner. Returns its kind, or &"" when nothing was destroyed.
func destroy_at(cell: Vector2i, cause: StringName) -> StringName:
	for i in _kinds.size():
		if _is_at[i].is_valid() and bool(_is_at[i].call(cell)):
			if _destroy[i].is_valid() and bool(_destroy[i].call(cell, cause)):
				return _kinds[i]
			return &""
	return &""
