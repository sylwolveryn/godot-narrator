class_name OriginHypothesis
extends Resource
## One account of the character's origin. Natures (what it is) can be ruled out through gameplay; deeds
## (what it did) are testimony and can never be struck. Instances: resources/origin/*.tres (tools/build_origin.gd).

enum Axis { NATURE, DEED }

@export var id: StringName = &""
@export var axis: Axis = Axis.NATURE
## One glyph shown for it in the ledger menu (task-043).
@export var sigil: String = ""
@export var label: String = ""
## Narration beat ids (authored in task-044): the claim that arms the trial, the beat on a strike, the beat on a recant.
@export var claim_beat_id: String = ""
@export var broken_beat_id: String = ""
@export var recant_beat_id: String = ""
## Null for deeds.
@export var trial: OriginTrial


func is_nature() -> bool:
	return axis == Axis.NATURE
