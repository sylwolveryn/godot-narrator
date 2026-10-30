class_name RevealConfig
extends Resource
## How the world is discovered. Instance: resources/config/reveal_config.tres.

## Cells within this distance (in cells) of the player are revealed.
@export var reveal_radius: float = 2.0
## When false the floor is never drawn: only walls, items and hazards appear, so the opening
## view is plain nothing around the character.
@export var reveal_floor: bool = false
## Cell type -> narration event announced the first time a cell of that type is revealed in a run.
@export var reveal_events: Dictionary[StringName, StringName] = {
	MapLegend.WALL: NarrationEvents.WALL_REVEALED,
	MapLegend.ITEM: NarrationEvents.ITEM_REVEALED,
	MapLegend.SPIKES: NarrationEvents.SPIKES_REVEALED,
}

@export_group("Memory style")
## How remembered cells (seen in an earlier run, not yet seen this run) are drawn.
## 0 keeps the colour, 1 turns it fully grey.
@export_range(0.0, 1.0) var memory_desaturation: float = 0.7
## Brightness multiplier for remembered cells.
@export_range(0.0, 1.0) var memory_brightness: float = 0.4
