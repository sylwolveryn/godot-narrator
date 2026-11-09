class_name BrainConfig
extends Resource
## Look of the brain form (task-091): a 2x2 block of Japanese glyphs that keep changing, with a constant glow and an
## aura in the world around it whose radius breathes between aura_min_tiles and aura_max_tiles.
## Defaults live here; BrainView and GlyphWorldView use BrainConfig.new() when no instance is set.

@export_group("Glyphs")
## Glyphs the four cells cycle through (any Unicode; drawn with font_names and the system fallback).
@export var glyphs: String = "脳知夢言語心魂記憶光闇声字読書思考意識あいうえおかきくけこアイウエオカキクケコ"
## Seconds between two changes of one cell (each cell has its own offset); plus up to cycle_jitter at random.
@export var cycle_seconds: float = 0.6
@export var cycle_jitter: float = 0.5
## Height of one glyph (world units), the gap between the cells, and the lift of the block's centre above the floor.
@export var glyph_size: float = 0.75
@export var cell_gap: float = 0.08
@export var centre_height: float = 1.2
@export var font_names: PackedStringArray = PackedStringArray(["Yu Gothic", "Meiryo", "MS Gothic", "Noto Sans CJK JP", "Microsoft YaHei"])
@export_range(8, 256) var font_size: int = 96
@export var font_weight: int = 700

@export_group("Glow")
## Glyph colour, the glow outline colour and its width; the glow breathes with glow_period (seconds).
@export var glyph_color: Color = Color(0.92, 0.97, 1.0)
@export var glow_color: Color = Color(0.55, 0.35, 1.0, 0.9)
@export_range(0, 64) var glow_size: int = 18
@export var glow_period: float = 2.4
@export_range(0.0, 1.0) var glow_breath: float = 0.35

@export_group("Aura")
## Radius of the world glow around the brain, in tiles, breathing between the two over aura_period seconds.
@export var aura_min_tiles: float = 3.0
@export var aura_max_tiles: float = 9.0
@export var aura_period: float = 4.0
## Colour and strength of the aura in the glyph-surface shader.
@export var aura_color: Color = Color(0.55, 0.4, 1.0)
@export var aura_strength: float = 0.9


## Aura radius in tiles at time `t` (seconds).
func aura_tiles(t: float) -> float:
	var k: float = 0.5 - 0.5 * cos(TAU * t / maxf(aura_period, 0.01))
	return lerpf(aura_min_tiles, aura_max_tiles, k)
