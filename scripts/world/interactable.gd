class_name Interactable
extends RefCounted
## Something the player can interact with (task-072). Register it with Interactables. It occupies `footprint` (map
## cells) and is in reach while the player stands within `reach` cells around it (reach 1 = the 8 neighbour cells of the
## footprint; standing on the footprint itself does not count). Interactables calls the three hooks below; subclasses
## (e.g. Cannon) override them. Pure data / logic, no nodes.

## Footprint in map cells.
var footprint: Rect2i = Rect2i()
## Cells around the footprint that are in reach; <= 0 uses InteractConfig.default_reach.
var reach: int = 0
## Disabled interactables are never in reach.
var enabled: bool = true


## True when a player standing in `cell` can reach this object.
func in_reach(cell: Vector2i, default_reach: int) -> bool:
	if not enabled or footprint.has_point(cell):
		return false
	var r: int = reach if reach > 0 else default_reach
	return footprint.grow(r).has_point(cell)


## The interact action went down while this object was in reach.
func interact_pressed() -> void:
	pass


## Every physics step while the action stays held: `delta` the step, `held` seconds since the press.
func interact_held(_delta: float, _held: float) -> void:
	pass


## The hold ended: released (cancelled = false) or cut short because the player left the reach, the menu opened, a
## teleport began or the run ended (cancelled = true). `held` = seconds since the press.
func interact_released(_held: float, _cancelled: bool) -> void:
	pass
