class_name RevealConfig
extends Resource
## How the world is discovered. Instance: resources/config/reveal_config.tres.

## Cells within this distance (in cells) of the player are revealed (when in line of sight).
@export var reveal_radius: float = 5.5
## Task-096: the reveal radius of each entity form is reveal_radius (or the map's) times this factor; a form not listed
## keeps 1. The player light reaches at least as far as the revealed area (MapReveal.light_reach).
@export var form_area_scale: Dictionary[StringName, float] = {
	EntityForm.SINGLE: 2.0,
	EntityForm.GROWN: 3.0,
}
## Only cells the player can see are revealed: cells of these types hide what lies behind them (they are seen themselves).
@export var line_of_sight: bool = true
@export var sight_blockers: Array[StringName] = [MapLegend.WALL, MapLegend.ITEM, MapLegend.VOID, MapLegend.DIRT]
## Sideways offset (cells) of the two extra sight rays; a cell is seen when any of the three rays gets through.
@export_range(0.0, 0.49) var sight_spread: float = 0.35
## When false the floor surfaces are never drawn: only walls, items and hazards appear.
@export var reveal_floor: bool = true
## Cell type -> narration event announced the first time a cell of that type is revealed in a run.
@export var reveal_events: Dictionary[StringName, StringName] = {
	MapLegend.WALL: NarrationEvents.WALL_REVEALED,
	MapLegend.ITEM: NarrationEvents.ITEM_REVEALED,
	MapLegend.SPIKES: NarrationEvents.SPIKES_REVEALED,
}

@export_group("Reveal animation")
## Seconds a newly seen cell takes to grow from darkness to its brightness (task-096: halved from 0.9).
@export var reveal_duration: float = 0.45
## Extra delay per cell of distance from the player, so the reveal travels outward (task-096: halved from 0.07).
@export var reveal_stagger_per_cell: float = 0.035
## Brightness overshoot of the reveal (1 = none), settling back to 1.
@export var reveal_overshoot: float = 1.06
## Point of the reveal (0..1) where the cyan glint peaks.
@export_range(0.0, 1.0) var reveal_glint_at: float = 0.6
## Seconds a remembered cell takes to turn into a live one (memory palette -> live palette; task-096: halved from 0.7).
@export var memory_to_seen_duration: float = 0.35
## Task-096: while the player sprints, cells that start revealing play faster by the player's sprint speed multiplier
## (their duration and stagger are divided by it). Off = the same speed at every pace.
@export var sprint_speeds_reveal: bool = true
