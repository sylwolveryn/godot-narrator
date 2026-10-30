class_name MapLegend
extends Resource
## Maps map-file characters to cell types. Instance: resources/config/map_legend.tres.

const VOID: StringName = &"void"
const FLOOR: StringName = &"floor"
const WALL: StringName = &"wall"
const SPAWN: StringName = &"spawn"
const ITEM: StringName = &"item"
const SPIKES: StringName = &"spikes"
const CORRUPT: StringName = &"corrupt"

## Character -> cell type.
@export var entries: Dictionary[String, StringName] = {
	" ": VOID,
	".": FLOOR,
	"#": WALL,
	"@": SPAWN,
	"*": ITEM,
	"^": SPIKES,
	"%": CORRUPT,
}
## Hazard cell type -> its data-driven definition (see HazardDefinition). Types missing here are harmless.
@export var hazards: Dictionary[StringName, HazardDefinition] = {}
## Cell type used for characters not in `entries` (a warning is logged).
@export var unknown_type: StringName = FLOOR


## Returns the cell type for a character, or &"" when the character is unknown.
func type_for(ch: String) -> StringName:
	if entries.has(ch):
		return entries[ch]
	return &""
