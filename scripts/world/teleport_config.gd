class_name TeleportConfig
extends Resource
## Teleports (task-068): the trip timeline (TeleportSystem), the camera drive, colour waves and pad look (TeleportView)
## and the player glyph dissolve (PlayerGlyphView). Instance: resources/config/teleport_config.tres (tools/build_resources.gd).
## The map side (ring character, channel order) lives in MapLegend.

@export_group("Trip")
## Whole trip in seconds; movement (and the in-world menu) is blocked for this long.
@export var trip_seconds: float = 3.0
## Glow-in at the source before the camera leaves.
@export var glow_in_seconds: float = 0.7
## Arrival at the end of the trip: the body is moved to the destination when it begins, the arrival wave plays.
@export var arrival_seconds: float = 0.6

@export_group("Camera")
## Several candidates: share of the travel time spent zooming out (and moving to the candidates' centre) and zooming
## back in on the chosen pad; the rest hovers zoomed out while the pings cycle.
@export_range(0.05, 0.5) var zoom_out_share: float = 0.3
@export_range(0.05, 0.5) var zoom_in_share: float = 0.3
## Single candidate: the camera eases straight to the destination over the whole travel.

@export_group("Waves")
## World units per second the ring of a wave expands. A wave of scale N lives sqrt(N) times longer and its band is
## sqrt(N) times wider, so it reaches sqrt(N) times further: N times the area.
@export var wave_speed: float = 7.5
## Half width of the bright band of a wave (world units, times sqrt(scale)).
@export var wave_band: float = 1.1
## Seconds a wave lives (times sqrt(scale)).
@export var wave_life: float = 1.1
## Brightness / colour gain of a full-strength wave.
@export var wave_strength: float = 3.0
## Ripples of the glow-in at the source (spread over glow_in_seconds) and of the arrival (one every
## arrival_ripple_spacing seconds from the arrival on; the last ones may outlast the trip while the destination reveals).
@export_range(1, 8) var glow_in_ripples: int = 3
@export_range(1, 8) var arrival_ripples: int = 3
@export var arrival_ripple_spacing: float = 0.3
## Several candidates: seconds between two pings (half-strength waves cycling over the candidates).
@export var ping_interval: float = 0.17
## Strength of a ping relative to a full wave.
@export_range(0.0, 1.0) var ping_strength: float = 0.5
## The arrival wave's area and intensity are multiplied by the candidate count, clamped to this.
@export var max_candidate_multiplier: float = 5.0
## Wave colours (vibrant), and how much a rainbow running along the ring replaces them (0 = flat colour).
@export var source_color: Color = Color(0.2, 0.95, 1.0)
@export var ping_color: Color = Color(1.0, 0.3, 0.95)
@export var arrival_color: Color = Color(1.0, 0.85, 0.25)
@export_range(0.0, 1.0) var wave_rainbow: float = 0.55
## Rainbow phase per world unit of distance and per second.
@export var rainbow_spatial: float = 0.12
@export var rainbow_speed: float = 0.6
## How much a wave densifies the glyphs it passes (added to the glyph brightness).
@export var wave_density: float = 1.0

@export_group("Pad look")
## Frame art drawn flat on the floor over the 3x3 footprint (square glyph pitch); the centre is left open for the
## channel rune. Broken pads draw `broken_chars` (picked per cell) at `broken_glyphs_per_cell` glyphs per cell.
@export var frame_lines: PackedStringArray = PackedStringArray([
	"/=-T-=\\",
	"|  :  |",
	"[     ]",
	"T: . :T",
	"[     ]",
	"|  :  |",
	"\\=-T-=/",
])
@export var broken_chars: String = "T/\\.,'`:;_"
@export_range(1, 4) var broken_glyphs_per_cell: int = 2
@export var font_names: PackedStringArray = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "monospace"])
@export_range(100, 999) var font_weight: int = 700
@export_range(8, 128) var font_size: int = 48
## Height of the flat frame above the floor (avoids z-fighting with the floor glyphs).
@export var frame_lift: float = 0.02
@export var frame_color: Color = Color(0.45, 0.6, 1.0)
@export var frame_glow_color: Color = Color(0.85, 1.0, 1.0)
@export var outline_color: Color = Color(0.01, 0.01, 0.04, 0.9)
@export_range(0, 32) var outline_size: int = 8
@export var broken_color: Color = Color(0.3, 0.3, 0.42, 0.85)
## The channel character standing in the middle (billboard), its height above the floor and size in world units.
@export var rune_color: Color = Color(0.4, 1.0, 0.85)
@export var rune_glow_color: Color = Color(1.0, 1.0, 1.0)
@export var rune_lift: float = 0.15
@export var rune_height: float = 0.9
## Rune scale gain at full glow (1 + gain).
@export var rune_glow_scale: float = 1.0
## Colour multiplier while a pad is only remembered.
@export var memory_tint: Color = Color(0.35, 0.38, 0.55, 0.75)
## Glow (0..1+) lost per second once nothing feeds it.
@export var glow_decay: float = 2.5
