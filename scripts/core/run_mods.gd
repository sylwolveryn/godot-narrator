class_name RunMods
extends RefCounted
## Run-only developer tweaks (task-098) that god's "New game with mods" passes on the game's command line, after `--`
## (user arguments, like MapLoader's `--map=`). They live only in the process that was started with them: nothing is
## written to the DB or the save, and a later start without the arguments plays normally.
##   --fog=0|1          0 = fog of war off (no depth fog, no darkness, every cell revealed); 1 = normal fog and darkness
##                      even on a map whose map_settings row turns them off. Absent = the map's own rules.
##   --sight=<percent>  scale of the reveal radius and the player light radius in every form (100 = unchanged).
## MapSettings.resolve applies the fog; MapReveal and GlyphWorldView apply the sight scale.

const FOG_PREFIX := "--fog="
const SIGHT_PREFIX := "--sight="
const PERCENT := 100.0
## Smallest accepted sight scale, so a typo can never hide the whole map.
const MIN_SIGHT_SCALE := 0.1

## Fog override: -1 = none (the map decides), 0 = off, 1 = on.
var fog: int = -1
## Factor on the reveal radius and the player light radius (1 = unchanged).
var sight_scale: float = 1.0

static var _current: RunMods


## The mods of this process (parsed once from OS.get_cmdline_user_args()).
static func current() -> RunMods:
	if _current == null:
		_current = parse(OS.get_cmdline_user_args())
	return _current


## Parses user arguments; the last occurrence of an argument wins, malformed values are ignored.
static func parse(args: PackedStringArray) -> RunMods:
	var mods := RunMods.new()
	for arg in args:
		if arg.begins_with(FOG_PREFIX):
			var v: String = arg.substr(FOG_PREFIX.length())
			if v.is_valid_int():
				mods.fog = 1 if int(v) != 0 else 0
		elif arg.begins_with(SIGHT_PREFIX):
			var p: String = arg.substr(SIGHT_PREFIX.length())
			if p.is_valid_float():
				mods.sight_scale = maxf(float(p) / PERCENT, MIN_SIGHT_SCALE)
	return mods


## True when a fog override is set.
func overrides_fog() -> bool:
	return fog >= 0


## The map_settings row with the fog override applied (a copy; the row itself is never changed).
func apply_to_row(row: Dictionary) -> Dictionary:
	if not overrides_fog():
		return row
	var out: Dictionary = row.duplicate()
	var on: bool = fog == 1
	out["fog_enabled"] = on
	out["darkness_enabled"] = on
	out["reveal_all"] = not on
	if on:
		out.erase("ambient_level")
	return out
