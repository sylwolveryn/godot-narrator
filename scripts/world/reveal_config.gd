class_name RevealConfig
extends Resource
## How the world is discovered. Instance: resources/config/reveal_config.tres.

## Cells within this distance (in cells) of the player are revealed.
@export var reveal_radius: float = 2.0
## When false the floor surfaces are never drawn: only walls, items and hazards appear.
@export var reveal_floor: bool = true
## Cell type -> narration event announced the first time a cell of that type is revealed in a run.
@export var reveal_events: Dictionary[StringName, StringName] = {
	MapLegend.WALL: NarrationEvents.WALL_REVEALED,
	MapLegend.ITEM: NarrationEvents.ITEM_REVEALED,
	MapLegend.SPIKES: NarrationEvents.SPIKES_REVEALED,
}

@export_group("Reveal animation")
## Seconds a newly seen cell takes to grow from darkness to its brightness.
@export var reveal_duration: float = 0.5
## Extra delay per cell of distance from the player, so the reveal travels outward.
@export var reveal_stagger_per_cell: float = 0.025
## Brightness overshoot of the reveal (1 = none), settling back to 1.
@export var reveal_overshoot: float = 1.15
## Point of the reveal (0..1) where the cyan glint peaks.
@export_range(0.0, 1.0) var reveal_glint_at: float = 0.6
## Seconds a remembered cell takes to turn into a live one (memory palette -> live palette).
@export var memory_to_seen_duration: float = 0.35
