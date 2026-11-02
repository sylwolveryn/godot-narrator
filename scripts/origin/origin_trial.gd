class_name OriginTrial
extends Resource
## The falsifier of one nature: a systemic condition that, once passed while the trial is armed, strikes the nature.
## Instances: resources/origin/trial_<id>.tres (tools/build_origin.gd). Checked by the trial monitor (task-041).

enum Kind { EROSION_ESCAPE, SINGLE_FORM_SURVIVE, DARK_IDLE, OBJECT_MOVED }

@export var kind: Kind = Kind.EROSION_ESCAPE
## Seconds the condition must hold (survive / stay idle). 0 = instant.
@export var seconds: float = 0.0
## Distance in cells (DARK_IDLE: minimum distance from any light-source cell). 0 = unused.
@export var distance: int = 0
## The trial stays dormant until the multi-glyph entity is unlocked.
@export var requires_entity_unlocked: bool = false
## The trial cannot be passed yet (its mechanic is not built): the narrator does not play the nature's claim.
## Flip it off when the mechanic exists (alien: task-045).
@export var dormant: bool = false
## EROSION_ESCAPE: erosion fraction (0..1 of the hazard threshold) that counts as "high" (the narrator's erosion_high
## event uses the same default, 70%). 0 = unused.
@export_range(0.0, 1.0) var erosion_fraction: float = 0.0
