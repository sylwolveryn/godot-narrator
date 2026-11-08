class_name CannonConfig
extends Resource
## Cannon `C` (task-073): turning, firing, the balls, the look and the boom. Instance:
## resources/config/cannon_config.tres (tools/build_resources.gd). The map footprint (1x1, 2x2, ...) comes from the
## LargeObjectDef of type `cannon_type` (resources/config/large_objects/cannon.tres).

## Large object type of the cannon cells (MapLegend.large_objects key).
@export var cannon_type: StringName = &"cannon"

@export_group("Turning")
## Facing of every cannon at run start, degrees on the ground (0 = +x, 90 = +z).
@export var start_facing_degrees: float = 0.0
## How fast a cannon turns away from an adjacent player, degrees per second.
@export var turn_speed_degrees: float = 220.0

@export_group("Firing")
## A press fires one ball at once. Held longer than this (seconds), autofire starts.
@export var autofire_delay: float = 2.0
## Autofire rate (balls per second) when it starts, and after `autofire_ramp` more seconds (it stays there).
@export var autofire_rate_start: float = 1.0
@export var autofire_rate_end: float = 5.0
@export var autofire_ramp: float = 4.0
## Full opening angle of the cone balls leave in, degrees (30 = +-15 around the facing).
@export_range(0.0, 180.0) var cone_degrees: float = 30.0

@export_group("Balls")
## Ball speed, cells per second.
@export var ball_speed_cells: float = 11.0
## A ball lives until it has travelled this many cells, then fades.
@export var range_cells: float = 100.0
## Seconds a ball takes to fade at the end of its range, and when it is spent on a hit.
@export var fade_seconds: float = 0.4
@export var hit_fade_seconds: float = 0.12
## Flight height (world units) and the gap between the footprint edge and the launch point (cells).
@export var ball_height: float = 0.55
@export var muzzle_margin_cells: float = 0.2
## Half-size of a ball glyph of a 1x1 cannon (world units); each extra footprint cell (the larger side) adds this share.
@export var ball_size: float = 0.2
@export var ball_size_per_cell: float = 0.35
## Collision radius against the player body (world units, added to the body radius).
@export var ball_radius: float = 0.12
## Speed kept on a bounce (1 = no dampening).
@export_range(0.0, 1.0) var bounce_keep: float = 1.0
## Balls alive at once (pool; the oldest is reused when it is full).
@export_range(1, 512) var capacity: int = 96

@export_group("Ball look")
## Atlas glyphs: the first is the ball, the rest the trail behind it (nearest first).
@export var ball_chars: String = "●o·."
@export var trail_spacing: float = 0.24
## Trail glyphs drawn behind a ball (at most ball_chars.length() - 1).
@export_range(0, 8) var trail_length: int = 3
@export var ball_color: Color = Color(1.0, 0.86, 0.55)
@export var trail_color: Color = Color(1.0, 0.45, 0.15)
@export var ball_rim: Color = Color(1.0, 0.98, 0.9)
@export var glyph_tile_px: int = 48
@export var glyph_font_px: int = 40
@export var glyph_font_names: PackedStringArray = PackedStringArray(["Consolas", "Segoe UI Symbol", "DejaVu Sans", "monospace"])

@export_group("Cannon look")
## Art per screen direction of the barrel, 0 = right, then clockwise on screen in 45 degree steps (1 = down-right,
## 2 = down, ... 6 = up, 7 = up-right). Every set has the same number of lines; drawn centred on the footprint.
@export var art: Array[PackedStringArray] = []
## Art character -> colour layer (other characters: the base layer " ").
@export var layer_of_char: Dictionary[String, String] = {"O": "m", "=": "b", "H": "b", "/": "b", "\\": "b", "o": "w", "-": "w"}
@export var layer_colors: Dictionary[String, Color] = {
	" ": Color(0.62, 0.66, 0.78),
	"b": Color(0.85, 0.88, 0.98),
	"m": Color(1.0, 0.62, 0.25),
	"w": Color(0.72, 0.5, 0.3),
}
## Muzzle flash: the muzzle layer glows this much brighter right after a shot, fading over flash_seconds.
@export var flash_color: Color = Color(1.0, 0.95, 0.6)
@export var flash_seconds: float = 0.18
@export var outline_color: Color = Color(0.01, 0.01, 0.03, 0.95)
@export_range(0, 32) var outline_size: int = 10
@export var font_names: PackedStringArray = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "monospace"])
@export_range(100, 999) var font_weight: int = 800
@export_range(8, 128) var font_size: int = 48
## Art width as a share of the footprint width.
@export var art_width_ratio: float = 2.0
## Aim marker lying on the floor in front of the muzzle (turns smoothly with the exact facing).
@export var aim_text: String = "›››"
@export var aim_color: Color = Color(1.0, 0.72, 0.3, 1.0)
## Aim marker length as a share of the footprint width, and its distance from the footprint edge (cells).
@export var aim_length: float = 1.0
@export var aim_offset_cells: float = 0.35
@export var aim_lift: float = 0.03
## Colour multiplier while the cannon is only remembered.
@export var memory_tint: Color = Color(0.35, 0.38, 0.55, 0.75)

@export_group("Sound")
## Override file: <override folder>/<path>, else <game folder>/<path>, else res://<path>; none = the synthesized boom.
@export var boom_file: String = "sfx/cannon_boom.mp3"
@export var boom_volume_db: float = -6.0
@export_range(0.0, 0.5) var boom_pitch_jitter: float = 0.08
## Booms closer together than this (seconds) are skipped.
@export var boom_min_interval: float = 0.05
## Synthesis: length (s), start / end of the low thump (Hz), its decay (s), noise burst length (s) and share,
## low-pass smoothing of the noise.
@export var boom_duration: float = 0.55
@export var boom_freq_start: float = 120.0
@export var boom_freq_end: float = 38.0
@export var boom_decay: float = 0.16
@export var boom_noise_seconds: float = 0.09
@export_range(0.0, 1.0) var boom_noise_share: float = 0.55
@export_range(0.0, 0.95) var boom_lowpass: float = 0.6
@export var boom_sample_rate: int = 22050
@export var boom_bus: StringName = &"Master"


## Ball half-size of a cannon with this footprint.
func ball_size_for(footprint: Vector2i) -> float:
	return ball_size * (1.0 + ball_size_per_cell * float(maxi(footprint.x, footprint.y) - 1))


## Autofire rate (balls / s) after `held` seconds of holding (0 before the delay).
func autofire_rate(held: float) -> float:
	if held < autofire_delay:
		return 0.0
	var k: float = clampf((held - autofire_delay) / maxf(autofire_ramp, 0.001), 0.0, 1.0)
	return lerpf(autofire_rate_start, autofire_rate_end, k * k * (3.0 - 2.0 * k))


## Screen direction index (0..7, see `art`) of a ground direction seen with the camera turned by `yaw_degrees`.
static func screen_dir_index(world_dir: Vector3, yaw_degrees: float) -> int:
	var s: Vector3 = world_dir.rotated(Vector3.UP, -deg_to_rad(yaw_degrees))
	var a: float = atan2(s.z, s.x)
	return posmod(roundi(a / (PI * 0.25)), 8)
