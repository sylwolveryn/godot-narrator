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
## A small pushable object (task-019). The cell under it is floor; MapData.objects records where it starts.
const OBJECT: StringName = &"object"

## Character -> cell type.
@export var entries: Dictionary[String, StringName] = {
	" ": VOID,
	".": FLOOR,
	"#": WALL,
	"@": SPAWN,
	"*": ITEM,
	"^": SPIKES,
	"%": CORRUPT,
	"o": OBJECT,
}
## Hazard cell type -> its data-driven definition (see HazardDefinition). Types missing here are harmless.
@export var hazards: Dictionary[StringName, HazardDefinition] = {}
## Multi-cell props (task-058): cell type -> definition. Their character (LargeObjectDef.character) needs no entry in
## `entries`; adjacent cells of one type merge into rectangular objects (LargeObjectMerger).
@export var large_objects: Dictionary[StringName, LargeObjectDef] = {}
## Teleports (task-068): an exact 3x3 ring of `teleport_char` around a channel character is a working teleport; any
## other group of `teleport_char` cells is broken. Parsed before `entries`, so a channel character inside a ring (e.g.
## `o`) is a channel, not its legend meaning. All teleport cells are floor.
@export var teleport_char: String = "T"
## Channel characters in channel order (the trip goes to the next higher channel present, wrapping around).
@export var teleport_channels: String = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
## Cell type used for characters not in `entries` (a warning is logged).
@export var unknown_type: StringName = FLOOR


## Returns the cell type for a character, or &"" when the character is unknown.
func type_for(ch: String) -> StringName:
	if entries.has(ch):
		return entries[ch]
	for type: StringName in large_objects:
		var def: LargeObjectDef = large_objects[type]
		if def != null and def.character == ch:
			return type
	return &""


## True for the cell type of a multi-cell prop.
func is_large(type: StringName) -> bool:
	return large_objects.has(type) and large_objects[type] != null


## Definition of a multi-cell prop type, null for any other type.
func large_def(type: StringName) -> LargeObjectDef:
	return large_objects.get(type, null)


## Large object types whose cells block discovery line of sight.
func sight_blocking_types() -> Array[StringName]:
	var out: Array[StringName] = []
	for type: StringName in large_objects:
		var def: LargeObjectDef = large_objects[type]
		if def != null and def.blocks_sight:
			out.append(type)
	return out
