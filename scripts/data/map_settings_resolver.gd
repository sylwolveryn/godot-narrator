class_name MapSettingsResolver
extends Node
## Data layer of the per-map visibility rules (task-069): the one owner of "which map_settings row applies". Picks the
## row of the loaded map (MapLoader.map_id) from the DB table `map_settings` (GameDatabase; the bundled seed when the
## server is offline). Readers (MapReveal, GlyphWorldView) resolve it over their own configs with MapSettings.resolve
## when a map loads, and again on `settings_changed` (every DB reload). Never writes anything.

## The DB tables were (re)read: the row of the loaded map may have changed.
signal settings_changed

@export var database: GameDatabase
@export var map_loader: MapLoader


func _ready() -> void:
	if database != null:
		database.tables_loaded.connect(func(_tables: Dictionary) -> void: settings_changed.emit())


## The map_settings row of a map id; empty when the map has none (= today's behaviour).
func row_for(map_id: StringName) -> Dictionary:
	if database == null or map_id == &"":
		return {}
	for row: Variant in database.rows(MapSettings.TABLE):
		if row is Dictionary and str((row as Dictionary).get(MapSettings.KEY, "")) == String(map_id):
			return row
	return {}


## The row of the loaded map.
func current_row() -> Dictionary:
	return row_for(map_loader.map_id) if map_loader != null else {}
