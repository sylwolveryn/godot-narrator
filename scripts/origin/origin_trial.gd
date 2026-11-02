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
