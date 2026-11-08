class_name MapSettings
extends RefCounted
## The visibility rules in effect on one map (task-069). Built by `resolve` from the map's DB row (table
## `map_settings`, one row per map id, see MapSettingsResolver) over the config defaults, so a map without a row plays
## exactly as before: reveal radius and line of sight from RevealConfig, player light radius and ambient level from
## GlyphWorldConfig, fog on, darkness on, nothing revealed up front. Pure data.
##
## Columns of a row (all optional; a negative number keeps the config value):
##   reveal_all          bool   every drawn cell is seen (live look, no memory look) from the start of every run
##   fog_enabled         bool   depth fog: the far side of the screen darkens and ambient fades with distance
##   darkness_enabled    bool   unlit surroundings: off = full light everywhere (GlyphWorldConfig.full_light_*),
##                              remembered cells drawn like seen ones
##   reveal_radius       float  cells around the player that get revealed
##   line_of_sight       bool   walls / items / dirt hide what lies behind them
##   player_light_radius float  world units of the player light
##   ambient_level       float  light level of unlit surfaces (wins over darkness_enabled = false)

const TABLE: String = "map_settings"
const KEY: String = "map_id"

var reveal_all: bool = false
var fog_enabled: bool = true
var darkness_enabled: bool = true
var reveal_radius: float = 0.0
var line_of_sight: bool = true
var player_light_radius: float = 0.0
var ambient_level: float = 0.0
## Colour of the ambient light (GlyphWorldConfig.ambient_color, or full_light_color without darkness).
var ambient_color: Color = Color.WHITE


## The effective settings of a row over the configs (null configs use their script defaults).
static func resolve(row: Dictionary, reveal: RevealConfig, look: GlyphWorldConfig) -> MapSettings:
	if reveal == null:
		reveal = RevealConfig.new()
	if look == null:
		look = GlyphWorldConfig.new()
	var s := MapSettings.new()
	s.reveal_all = _flag(row, "reveal_all", false)
	s.fog_enabled = _flag(row, "fog_enabled", true)
	s.darkness_enabled = _flag(row, "darkness_enabled", true)
	s.reveal_radius = _number(row, "reveal_radius", reveal.reveal_radius)
	s.line_of_sight = _flag(row, "line_of_sight", reveal.line_of_sight)
	s.player_light_radius = _number(row, "player_light_radius", look.player_light_radius)
	s.ambient_level = look.ambient_level if s.darkness_enabled else look.full_light_ambient
	s.ambient_level = _number(row, "ambient_level", s.ambient_level)
	s.ambient_color = look.ambient_color if s.darkness_enabled else look.full_light_color
	return s


static func _flag(row: Dictionary, column: String, fallback: bool) -> bool:
	var v: Variant = row.get(column, null)
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	return fallback


static func _number(row: Dictionary, column: String, fallback: float) -> float:
	var v: Variant = row.get(column, null)
	if (v is int or v is float) and float(v) >= 0.0:
		return float(v)
	return fallback
