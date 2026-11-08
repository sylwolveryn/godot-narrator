class_name Consumable
extends RefCounted
## Kinds of things the player consumes (eats or picks up). Carried by SignalBus.consumed, counted per kind in
## PersistentProgress.consumed (SaveService) and in the DB table player_consumed (PlayerRecord). Add a kind here and
## emit SignalBus.consumed where it is consumed; the Items menu lists every kind with a label in MenuConfig.items_labels.

const DIRT: StringName = &"dirt"
const DIAMOND: StringName = &"diamond"
