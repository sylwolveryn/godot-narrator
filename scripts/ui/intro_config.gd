class_name IntroConfig
extends Resource
## Timings and look of the intro: black screen, abstract wave, then dissolve into the world.
## Instance: resources/config/intro_config.tres.

@export_group("Timings (seconds)")
## Pure black before anything appears.
@export var black_hold: float = 1.0
## Wave intensity fades in.
@export var wave_fade_in: float = 1.0
## Wave at full intensity.
@export var wave_hold: float = 1.8
## Hand-off to the spawn step happens at the start of this phase: the wave and the black
## veil dissolve while the world (and the player) are already there.
@export var reveal_duration: float = 1.4
## Share of the reveal in which the wave fades out; the veil lifts over the whole reveal.
@export_range(0.2, 1.0, 0.05) var wave_dissolve_fraction: float = 0.7
## Multiplier applied to every timing when the intro replays after a death.
@export_range(0.0, 1.0, 0.05) var restart_time_scale: float = 0.35

@export_group("Wave")
@export var wave_color: Color = Color("#5FF2E8")
## Number of horizontal wave lines.
@export_range(1, 12) var line_count: int = 5
## Crests across the screen width.
@export var frequency: float = 2.2
## Travel speed in radians per second.
@export var speed: float = 1.6
## Vertical amplitude as a fraction of screen height.
@export_range(0.0, 0.5) var amplitude: float = 0.14
## Vertical spacing between lines as a fraction of screen height.
@export_range(0.0, 0.3) var line_spacing: float = 0.05
## Thickness of a wave line, as a fraction of screen height.
@export_range(0.005, 0.2) var thickness: float = 0.022
## Size of the dotted cells the wave is quantised to, in reference pixels (scaled at runtime).
@export var cell_size: Vector2i = Vector2i(20, 36)
