class_name OriginConfig
extends Resource
## Tunables and hypothesis list of the origin rule-out system. Instance: resources/config/origin_config.tres.

## All hypotheses: 4 natures then 2 deeds.
@export var hypotheses: Array[OriginHypothesis] = []
## Natures that must always stay alive. Values below HARD_MIN_ALIVE_NATURE are clamped to it with an error.
@export var min_alive_nature: int = 2
## Strikes allowed per run.
@export var max_strikes_per_run: int = 1
## A recanted nature's trial threshold is multiplied by this per previous strike.
@export var retry_scale: float = 1.5
## Fraction of glyphs that stay unsettled in a line whose supported natures are all struck (task-042).
@export_range(0.0, 1.0) var doubt_scramble: float = 0.3
## At the floor, prefer beats that support both surviving natures (task-042).
@export var tie_prefer_dual_support: bool = true

## The guarantee never drops below this, whatever the config says.
const HARD_MIN_ALIVE_NATURE: int = 2


func find(id: StringName) -> OriginHypothesis:
	for h in hypotheses:
		if h != null and h.id == id:
			return h
	return null


func nature_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for h in hypotheses:
		if h != null and h.is_nature():
			out.append(String(h.id))
	return out


func deed_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for h in hypotheses:
		if h != null and not h.is_nature():
			out.append(String(h.id))
	return out


## min_alive_nature after clamping to [HARD_MIN_ALIVE_NATURE, number of natures].
func effective_min_alive() -> int:
	return clampi(min_alive_nature, HARD_MIN_ALIVE_NATURE, maxi(HARD_MIN_ALIVE_NATURE, nature_ids().size()))
