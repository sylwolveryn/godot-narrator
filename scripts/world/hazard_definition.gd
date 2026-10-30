class_name HazardDefinition
extends Resource
## Data for one hazard type. Instances: resources/config/hazard_spikes.tres and
## hazard_corrupting.tres, referenced from MapLegend.hazards by cell type.

## The MapLegend cell type this definition applies to (e.g. MapLegend.SPIKES).
@export var kind: StringName = &""
## Cause passed to SignalBus.run_end_requested when this hazard ends the run.
@export var end_cause: StringName = &""
## True: touching the hazard ends the run at once (erosion values below are unused).
@export var lethal_on_touch: bool = false
## Erosion gained per second while the player stands inside the hazard.
@export_range(0.0, 100.0, 0.01) var erosion_rate: float = 0.0
## Erosion at which the run ends.
@export_range(0.01, 100.0, 0.01) var erosion_threshold: float = 1.0
## Erosion lost per second while the player is outside every erosive hazard.
@export_range(0.0, 100.0, 0.01) var recovery_rate: float = 0.0
## Colour the hazard gives the player's glyph while eroding and the shards when it kills.
@export var tint: Color = Color(1.0, 0.3, 0.25)
