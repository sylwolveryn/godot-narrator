class_name GlyphWorldConfig
extends Resource
## Look and light of the glyph-surface world (shaders/glyph_surface.gdshader). Static values are
## applied to the world material by GlyphWorldView. Instance: resources/config/glyph_world_config.tres.

@export_group("Glyph grid")
## Height of one glyph cell on screen, in world units (orthographic size scale).
@export var cell_screen: float = 0.19
## Glyph cell width / height.
@export var cell_aspect: float = 0.62
## Fraction of an atlas tile's width shown per cell (crops side bearing).
@export_range(0.1, 1.0) var glyph_crop: float = 0.62

@export_group("Light and colour")
## Light level of unlit surfaces.
@export_range(0.0, 1.0) var ambient_level: float = 0.46
## How strongly the light colour tints floor and wall glyphs (0 = palette only).
@export_range(0.0, 1.0) var tint_mix: float = 0.75
## Per surface type (GlyphSurfaceType order: wall, floor, spikes, corruption, item).
@export var palette_dark: PackedColorArray = PackedColorArray([
	Color(0.20, 0.27, 0.45), Color(0.24, 0.24, 0.34), Color(0.45, 0.12, 0.10), Color(0.30, 0.12, 0.55), Color(0.10, 0.45, 0.75)])
@export var palette_bright: PackedColorArray = PackedColorArray([
	Color(0.60, 0.76, 1.00), Color(1.00, 0.74, 0.44), Color(1.00, 0.40, 0.22), Color(1.00, 0.35, 0.90), Color(0.75, 0.97, 1.00)])
## Self-lit glow added to the brightness of each surface type, so hazards and items glow in the dark.
@export var emissive: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.18, 0.38, 0.85])

## Corruption colours slide between these two.
@export var corrupt_hue_a: Color = Color(0.55, 0.28, 1.0)
@export var corrupt_hue_b: Color = Color(1.0, 0.28, 0.75)
## Colour added to a cell while its reveal glints.
@export var glint_color: Color = Color(0.2, 0.8, 1.0)

@export_group("Memory")
## Remembered (not currently seen) cells are drawn at this fraction of their brightness.
@export_range(0.0, 1.0) var memory_dim: float = 0.8
## Saturation kept by remembered cells (0 = grey).
@export_range(0.0, 1.0) var memory_saturation: float = 0.1
## Colour multiplier of remembered cells (cool: less red, more blue).
@export var memory_tint: Color = Color(0.62, 0.8, 1.15)
## Share of its light a remembered cell uses to pick its glyph (1 = as dense as a live cell, lower = sparser glyphs).
@export_range(0.0, 1.0) var memory_density: float = 0.7
## Least brightness (glyph density) a remembered cell has, so it stays readable outside the light.
@export_range(0.0, 1.0) var memory_floor: float = 0.3
## Share of the glyphs that are missing on remembered cells (they come back when the cell is seen again).
@export_range(0.0, 1.0) var memory_dropout: float = 0.3
## Share of the self-lit glow of items and hazards kept on remembered cells.
@export_range(0.0, 1.0) var memory_emit: float = 0.25

@export_group("Reveal")
## How far apart (in reveal progress, 0..1) the glyphs of one cell materialise: 0 = all together, 1 = one after the other.
@export_range(0.0, 2.0) var reveal_spread: float = 0.8

@export_group("Player light")
@export var player_light_color: Color = Color(1.0, 0.82, 0.5)
@export var player_light_intensity: float = 1.7
@export var player_light_radius: float = 7.5
## Height of the light above the floor.
@export var player_light_height: float = 1.1

@export_group("Static lights")
## Static lights the shader can use besides the player light (the shader loop holds 8 in total).
@export_range(0, 7) var max_static_lights: int = 7
@export var item_light_color: Color = Color(0.25, 0.65, 1.0)
@export var item_light_intensity: float = 1.1
@export var item_light_radius: float = 4.6
@export var item_light_height: float = 0.9
@export var spike_light_color: Color = Color(1.0, 0.35, 0.18)
@export var spike_light_intensity: float = 1.0
@export var spike_light_radius: float = 3.4
@export var spike_light_height: float = 0.5
@export var corrupt_light_color: Color = Color(0.75, 0.25, 1.0)
@export var corrupt_light_intensity: float = 1.0
@export var corrupt_light_radius: float = 4.4
@export var corrupt_light_height: float = 0.6
## A patch of hazard cells (4-connected) gets one light, with the radius widened by this per cell of extent.
@export var patch_radius_per_cell: float = 0.35

@export_group("Halos")
## Soft additive glow sprites over items, spikes and corruption (GlyphHaloField). The arrays are indexed
## item, spikes, corruption; the colour and height are those of the static light of the same kind.
## Radius of the glow in world units.
@export var halo_size: PackedFloat32Array = PackedFloat32Array([1.4, 1.0, 1.1])
@export var halo_intensity: PackedFloat32Array = PackedFloat32Array([0.7, 0.4, 0.38])
## 0 = round bloom at the light height, 1 = the glow pools on the floor under it.
@export var halo_pool: PackedFloat32Array = PackedFloat32Array([0.4, 0.85, 0.8])
## Seconds of one breath of the glow, and how much of its brightness it breathes (keep slow: at most 0.5 Hz, +-0.25).
@export var halo_breath_period: PackedFloat32Array = PackedFloat32Array([4.0, 2.5, 5.0])
@export var halo_breath_amount: PackedFloat32Array = PackedFloat32Array([0.08, 0.15, 0.22])
## Breath phase shift per map cell (x + y), so neighbouring glows breathe in a travelling wave.
@export var halo_phase_step: float = 0.7
## Share of the glow kept on remembered (not currently seen) cells; 0 = no halo on memory.
@export_range(0.0, 1.0) var halo_memory: float = 0.0
## Halo quads are pushed this far towards the camera so the item pillars and the floor never clip them.
@export var halo_lift: float = 0.5

@export_group("Carved stone")
## Wall masonry: block width and course height in world units (courses are offset by half a block).
@export var wall_block_size: Vector2 = Vector2(0.66, 0.5)
## Floor flagstone size in world units.
@export var floor_tile_size: float = 0.5
## Width of block seams (world units; a seam is resolved per glyph cell, so about one glyph wide).
@export var seam_width: float = 0.07
## Brightness kept on a seam.
@export_range(0.0, 1.0) var seam_dim: float = 0.62
## Static brightness variation per block (+- this fraction).
@export_range(0.0, 1.0) var block_variation: float = 0.3
## Width of the rim on free edges of wall tops, world units (rims on side faces are one glyph wide).
@export var edge_width: float = 0.11
## Rim cells gain this fraction of the light they catch (so rims shine near light only).
@export var edge_gain: float = 2.2
## Light every rim catches even in the dark (keeps the outline of walls faintly readable).
@export var edge_ambient: float = 0.24
## Brightness kept at the foot of a wall, fading to full over wall_ao_height.
@export_range(0.0, 1.0) var wall_base_dark: float = 0.78
@export var wall_ao_height: float = 0.7
## Ambient on wall tops relative to the floor: the tops are dark stone, the rims carry the outline.
@export_range(0.0, 1.0) var wall_top_ambient: float = 0.95
## 0 = linear light falloff, 1 = quadratic: the light concentrates near its source, glyphs get denser close to it.
@export_range(0.0, 1.0) var light_falloff_sharp: float = 0.3

@export_group("Depth")
## Ambient light fades from full to depth_ambient_min between these distances from the player light (world units).
@export var depth_near: float = 3.0
@export var depth_far: float = 9.0
@export_range(0.0, 1.0) var depth_ambient_min: float = 0.72
## Darkening towards the top of the screen (far side of the map), starting at fog_start (fraction of the screen height from the bottom).
@export_range(0.0, 1.0) var fog_strength: float = 0.15
@export_range(0.0, 1.0) var fog_start: float = 0.3

@export_group("Light occlusion")
## Off draws every light through walls (for comparison).
@export var occlusion_enabled: bool = true
## Sideways offset (in cells) of the two extra rays per cell; gives soft shadow edges.
@export_range(0.0, 0.5) var occlusion_penumbra: float = 0.35
## Seconds the player light takes to adapt its shadows after the player changes cell.
@export var occlusion_blend_time: float = 0.18

@export_group("Static light fade")
## Seconds a static light takes to fade in when it is revealed or comes into range, and to fade out again.
@export var static_light_fade_in: float = 0.9
@export var static_light_fade_out: float = 0.6

@export_group("Wall cut-away")
## Surfaces closer to the camera than the player, within this radius of the view ray through the
## player, are cut away so walls never hide the player.
@export var cutaway_radius: float = 1.1
## Width of the soft edge around the cut-away: glyphs dim and drop out (per glyph cell) across it.
@export var cutaway_soft: float = 0.9
## Height above the player's feet the view ray is aimed at.
@export var cutaway_height: float = 0.5
## Distance along the view ray (towards the camera) before the cut starts, so the floor under the player stays.
@export var cutaway_margin: float = 0.15
## Brightness kept by the glyphs at the very edge of the cut-away (they dim before they drop out).
@export_range(0.0, 1.0) var cutaway_edge_dim: float = 0.35
