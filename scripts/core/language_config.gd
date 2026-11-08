class_name LanguageConfig
extends Resource
## Tuning of the language understanding progression (task-065). Understanding of the SELECTED language is the core
## progress meter: it grows with walking, deaths and discoveries; at `unlock_at_percent` the Language menu opens the
## next language. Instance: resources/config/language_config.tres, built by tools/build_resources.gd.

@export_group("Start")
## Language a new game starts with (unlocked and selected).
@export var start_language: StringName = &"EN_GB"
## Understanding (percent) of the start language on a new game.
@export_range(0.0, 100.0) var start_percent: float = 0.0
## Highest understanding (percent); gains are clamped to it.
@export_range(0.0, 100.0) var max_percent: float = 100.0

@export_group("Gains")
## +1% for this many map cells walked (SignalBus.player_stepped).
@export var tiles_per_percent: int = 20
## Percent gained by the selected language per step quota, per run end (every run end is a death) and the first time
## ever a new type of cell is discovered.
@export var percent_per_steps: float = 1.0
@export var percent_per_death: float = 1.0
@export var percent_per_new_type: float = 3.0
## Cell types that never count as a discovery.
@export var ignored_types: PackedStringArray = PackedStringArray(["void"])

@export_group("Unlock")
## Opening the Language list with the selected language at or above this unlocks the next locked language.
@export_range(0.0, 100.0) var unlock_at_percent: float = 60.0
## Understanding (percent) a freshly unlocked language starts with.
@export_range(0.0, 100.0) var unlocked_start_percent: float = 1.0
## Unlock order after the start language (DB language_def order).
@export var unlock_order: PackedStringArray = PackedStringArray(["HU_HU", "ALIEN", "MATRIX", "DREAM", "DE_DE", "RU_RU", "JP_HAN", "JP_KANA"])
## Storm played on an unlock: radius / duration <= 0 use the StormConfig defaults, tint alpha 0 uses the default tint.
@export var unlock_storm_radius: float = 0.0
@export var unlock_storm_duration: float = 0.0
@export var unlock_storm_tint: Color = Color(0, 0, 0, 0)

@export_group("Menu")
## Shown names per language id.
@export var display_names: Dictionary[StringName, String] = {
	&"EN_GB": "English",
	&"HU_HU": "Hungarian",
	&"ALIEN": "Alien",
	&"MATRIX": "Matrix",
	&"DREAM": "Dream",
	&"DE_DE": "German",
	&"RU_RU": "Russian",
	&"JP_HAN": "Japanese Kanji",
	&"JP_KANA": "Japanese Kana",
}
## One Language list entry: name and whole percent.
@export var entry_format: String = "%s %d%%"


## Every known language id: the start language first, then the unlock order.
func all_languages() -> PackedStringArray:
	var out := PackedStringArray([String(start_language)])
	for id in unlock_order:
		if not out.has(id):
			out.append(id)
	return out


func display_name(language: StringName) -> String:
	return display_names.get(language, String(language))
