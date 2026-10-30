class_name PaletteConfig
extends Resource
## Colour palette ("Midnight Neon", docs/visual_direction.md section 2). Every element is a
## three-stop gradient (shadow, mid, highlight) sampled by luminance; the post-process bakes them
## into a 256x16 lookup texture at boot. Instance: resources/config/palette_config.tres.

## LUT rows. Rows 1..5 match the material ids written by the world shader.
const ROW_VOID := 0
const ROW_WALL := 1
const ROW_FLOOR := 2
const ROW_ITEM := 3
const ROW_SPIKES := 4
const ROW_CORRUPT := 5
const ROW_CORRUPT_ALT := 6
const ROW_MEMORY := 7
const LUT_WIDTH := 256
const LUT_HEIGHT := 16

@export var wall: Gradient = _gradient("#0B2A3A", "#1F7A8C", "#5FF2E8")
@export var floor_tiles: Gradient = _gradient("#10162A", "#2E3A5E", "#8FA3D9")
@export var item: Gradient = _gradient("#7A3E0C", "#FFB238", "#FFF1B0")
@export var spikes: Gradient = _gradient("#3A0A1A", "#FF3D5A", "#FFB08A")
## Corruption slides between these two gradients (violet and magenta).
@export var corrupt: Gradient = _gradient("#1C0630", "#9D3CFF", "#C46BFF")
@export var corrupt_alt: Gradient = _gradient("#2A0638", "#E03CE6", "#FF4FD8")
@export var memory: Gradient = _gradient("#202C52", "#5775B8", "#94B4EE")
@export var void_color: Color = Color("#000000")

@export_group("Background")
@export var bg_centre: Color = Color("#0B1020")
@export var bg_edge: Color = Color("#030409")

@export_group("Light")
## Warm amber tint of the player light.
@export var light_tint: Color = Color("#FFC27A")

@export_group("Palette sets")
## Optional per-run palette overrides (index = run index modulo size). Empty in M1.
## (Untyped: a typed array of its own class would keep the script alive at exit.)
@export var palette_by_run: Array = []


static func _gradient(shadow: String, mid: String, highlight: String) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(shadow), Color(mid), Color(highlight)])
	return g


## Palette to use for a run (palette_by_run, else this one).
func for_run(run_index: int) -> PaletteConfig:
	if palette_by_run.is_empty():
		return self
	var other: PaletteConfig = palette_by_run[posmod(run_index, palette_by_run.size())] as PaletteConfig
	return other if other != null else self


## Bakes the gradients into the lookup texture: one row per type, u (0..1) along x.
func build_lut() -> ImageTexture:
	var img := Image.create(LUT_WIDTH, LUT_HEIGHT, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	var rows: Dictionary[int, Gradient] = {
		ROW_WALL: wall, ROW_FLOOR: floor_tiles, ROW_ITEM: item, ROW_SPIKES: spikes,
		ROW_CORRUPT: corrupt, ROW_CORRUPT_ALT: corrupt_alt, ROW_MEMORY: memory,
	}
	for x in LUT_WIDTH:
		img.set_pixel(x, ROW_VOID, void_color)
	for row: int in rows:
		var g: Gradient = rows[row]
		for x in LUT_WIDTH:
			var c: Color = g.sample(float(x) / float(LUT_WIDTH - 1))
			c.a = 1.0
			img.set_pixel(x, row, c)
	return ImageTexture.create_from_image(img)
