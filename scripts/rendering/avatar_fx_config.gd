class_name AvatarFxConfig
extends Resource
## Look and feel of the player avatar (task-056/057): crystal glow, ink trail, lean and stretch. The live values come
## from the DB table `avatar_fx` (row `profile`); these exported values are the fallback until it is read.
## Instance: resources/config/avatar_fx_config.tres.

## DB row used.
@export var profile: String = "default"

@export_group("Crystal glow")
## Colours the glyph slowly shifts through (per facet, each with its own phase).
@export var crystal_palette: PackedColorArray = PackedColorArray([
	Color("#9ff0ff"), Color("#8fa8ff"), Color("#d99cff"), Color("#ffe7b0")])
## Palette cycles per second.
@export var crystal_speed: float = 0.08
## Share of the crystal colour in the glyph and its halo.
@export_range(0.0, 1.0) var crystal_strength: float = 0.55
## Facets across the glyph tile.
@export var crystal_facets: float = 5.0
## Share of facets that briefly sparkle.
@export_range(0.0, 1.0) var crystal_sparkle: float = 0.04
## Most palette colours the shader holds (its CRYSTAL_MAX).
@export var crystal_max_colors: int = 6

@export_group("Understanding look")
## Task-066: the player glyph follows the selected language's understanding (0..1). Config only (no DB columns yet;
## with_row reads them when a row has them).
## Below this understanding the glyph is hollow (outline only, no filled body).
@export_range(0.0, 1.0) var hollow_below: float = 0.06
## Understanding span over which the body fills in after hollow_below.
@export_range(0.0, 1.0) var fill_fade: float = 0.03
## The glow (halo, crystal shimmer and sparkle) is off below this understanding and rises to the full look at 1.
@export_range(0.0, 1.0) var glow_start: float = 0.06
## Shape of that rise (1 = linear).
@export var glow_exponent: float = 1.0
## Colour at 0 understanding: saturation and brightness multipliers (blunt, darker).
@export var blunt_saturation: float = 0.35
@export var blunt_brightness: float = 0.72
## Colour at full understanding: a bit more vivid than the plain look (1, 1).
@export var vivid_saturation: float = 1.15
@export var vivid_brightness: float = 1.12

@export_group("Ink trail")
@export var trail_enabled: bool = true
@export var trail_chars: String = ".,:;'`"
@export var trail_color: Color = Color("#8a6bff")
@export var trail_rim: Color = Color("#efe6ff")
## Seconds a drop takes to fade out.
@export var trail_lifetime: float = 0.8
## World units travelled between two drops.
@export var trail_spacing: float = 0.22
## Drop half-size (world units) and its growth while fading (share of the size).
@export var trail_size: float = 0.24
@export var trail_spread: float = 0.6
## Sideways random offset of a drop, world units.
@export var trail_jitter: float = 0.12
## Height of the drops above the floor (keeps them off the floor surface).
@export var trail_height: float = 0.03
## Drops kept at once (ring buffer); the oldest is reused.
@export var trail_capacity: int = 48
## Characters rasterised into the trail atlas, and the atlas tile / font size in pixels.
@export var trail_max_chars: int = 8
@export var trail_tile_px: int = 48
@export var trail_font_px: int = 40
@export var trail_font_names: PackedStringArray = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "monospace"])

@export_group("Lean and stretch")
## Screen-space lean into the motion at full speed (shear of the glyph quad).
@export var lean_amount: float = 0.18
## Stretch when speeding up, squash when braking (share of the height at full acceleration).
@export var stretch_amount: float = 0.12
## Seconds the lean and stretch take to follow the motion.
@export var feel_smoothing: float = 0.12
## Acceleration (units/s^2) that counts as full stretch.
@export var stretch_reference_accel: float = 14.0


## A copy with the values of a DB `avatar_fx` row applied (missing or invalid columns keep this config's values).
func with_row(row: Dictionary) -> AvatarFxConfig:
	var out: AvatarFxConfig = duplicate() as AvatarFxConfig
	if row.is_empty():
		return out
	var palette := PackedColorArray()
	for part in str(row.get("crystal_palette", "")).split(",", false):
		if Color.html_is_valid(part.strip_edges()) and palette.size() < crystal_max_colors:
			palette.append(Color.html(part.strip_edges()))
	if not palette.is_empty():
		out.crystal_palette = palette
	for key: String in ["crystal_speed", "crystal_strength", "crystal_facets", "crystal_sparkle", "trail_lifetime",
			"trail_spacing", "trail_size", "trail_spread", "trail_jitter", "lean_amount", "stretch_amount", "feel_smoothing",
			"hollow_below", "fill_fade", "glow_start", "glow_exponent", "blunt_saturation", "blunt_brightness",
			"vivid_saturation", "vivid_brightness"]:
		if row.has(key):
			out.set(key, float(row[key]))
	if row.has("trail_enabled"):
		out.trail_enabled = bool(row["trail_enabled"])
	if str(row.get("trail_chars", "")) != "":
		out.trail_chars = str(row["trail_chars"])
	for key: String in ["trail_color", "trail_rim"]:
		if Color.html_is_valid(str(row.get(key, "")).strip_edges()):
			out.set(key, Color.html(str(row[key]).strip_edges()))
	return out


## Hollow amount (1 = outline only) at an understanding.
func hollow_at(understanding: float) -> float:
	return 1.0 - smoothstep(hollow_below, hollow_below + maxf(fill_fade, 0.0001), understanding)


## Glow share (0 = none, 1 = the full look) at an understanding.
func glow_at(understanding: float) -> float:
	if understanding < glow_start:
		return 0.0
	return pow(clampf((understanding - glow_start) / maxf(1.0 - glow_start, 0.0001), 0.0, 1.0), maxf(glow_exponent, 0.001))


## (saturation, brightness) multipliers of the glyph colour at an understanding.
func colour_grade_at(understanding: float) -> Vector2:
	var u: float = clampf(understanding, 0.0, 1.0)
	return Vector2(lerpf(blunt_saturation, vivid_saturation, u), lerpf(blunt_brightness, vivid_brightness, u))


## The config for a DB copy: the `avatar_fx` row of `profile`, applied over this config.
func from_tables(tables: Dictionary) -> AvatarFxConfig:
	for row: Variant in tables.get("avatar_fx", []):
		if row is Dictionary and str((row as Dictionary).get("profile", "")) == profile:
			return with_row(row)
	return with_row({})
