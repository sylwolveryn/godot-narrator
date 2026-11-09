class_name Crafting
extends Node
## Crafting from dirt (task-088), data layer. Recipes are the DB table `craft_def` (id, label, research_order,
## research_cost, craft_cost; GameDatabase). Research spends dirt and teaches the next unknown recipe in research order;
## crafting a known recipe spends its craft cost and counts it. Known recipes, crafted counts and the spent dirt are
## saved through SaveService. The in-world menu asks through SignalBus.research_requested / craft_requested and reads
## the page from entries(); this node answers with narration events (RESEARCH_DONE + CRAFT_LEARNED, CRAFTED,
## CRAFT_REFUSED when the dirt is not enough).

const TABLE: String = "craft_def"
## What research and crafting spend.
const RESOURCE: StringName = Consumable.DIRT

@export var save_service: SaveService
@export var database: GameDatabase


func _ready() -> void:
	SignalBus.research_requested.connect(research)
	SignalBus.craft_requested.connect(craft)


## All recipes, in research order.
func recipes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if database == null:
		return out
	for row: Variant in database.rows(TABLE):
		if row is Dictionary and str((row as Dictionary).get("id", "")) != "":
			out.append(row)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("research_order", 0)) < int(b.get("research_order", 0)))
	return out


## Known recipes, in research order.
func known() -> Array[Dictionary]:
	return recipes().filter(func(r: Dictionary) -> bool: return _progress().known_crafts.has(str(r["id"])))


## The recipe research would teach next, or an empty dictionary when every recipe is known.
func next_research() -> Dictionary:
	for r in recipes():
		if not _progress().known_crafts.has(str(r["id"])):
			return r
	return {}


## Dirt the player has to spend.
func stock() -> int:
	return save_service.stock(RESOURCE) if save_service != null else 0


## Spends research_cost of the next recipe and learns it. False (and CRAFT_REFUSED) when there is not enough dirt;
## false without narration when nothing is left to learn.
func research() -> bool:
	var next: Dictionary = next_research()
	if next.is_empty() or save_service == null:
		return false
	if not save_service.spend(RESOURCE, int(next.get("research_cost", 0))):
		SignalBus.narration_event.emit(NarrationEvents.CRAFT_REFUSED)
		return false
	save_service.learn_craft(str(next["id"]))
	SignalBus.narration_event.emit(NarrationEvents.RESEARCH_DONE)
	SignalBus.narration_event.emit(NarrationEvents.CRAFT_LEARNED)
	return true


## Crafts a known recipe: spends its craft_cost and counts it. False for an unknown recipe, false and CRAFT_REFUSED
## when there is not enough dirt.
func craft(id: StringName) -> bool:
	if save_service == null or not _progress().known_crafts.has(String(id)):
		return false
	var recipe: Dictionary = {}
	for r in recipes():
		if str(r["id"]) == String(id):
			recipe = r
	if recipe.is_empty():
		return false
	if not save_service.spend(RESOURCE, int(recipe.get("craft_cost", 0))):
		SignalBus.narration_event.emit(NarrationEvents.CRAFT_REFUSED)
		return false
	save_service.add_crafted(String(id))
	SignalBus.narration_event.emit(NarrationEvents.CRAFTED)
	return true


## How many of a recipe were crafted.
func crafted(id: StringName) -> int:
	return int(_progress().crafted.get(String(id), 0)) if save_service != null else 0


func _progress() -> PersistentProgress:
	return save_service.progress
