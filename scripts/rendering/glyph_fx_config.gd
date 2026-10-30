class_name GlyphFxConfig
extends Resource
## Presentation tuning for the overlay glyph effects (docs/visual_direction.md sections 5 and 6):
## the identity glyph morphing under erosion, the death fragments and the flicker limits that
## every effect must respect. Instance: resources/config/glyph_fx_config.tres.

@export_group("Morph (visual direction)")
## Mid-morph scale dip and glow boost: the glyph shrinks to this scale and glows this much more.
@export_range(0.5, 1.0) var morph_scale_dip: float = 0.92
@export_range(0.0, 1.0) var morph_glow_boost: float = 0.15
@export var default_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var default_trans: Tween.TransitionType = Tween.TRANS_CUBIC

@export_group("Flicker limits (visual direction)")
## Ambient cells never change target glyph more often than this (per second).
@export var max_glyph_changes_per_sec: float = 2.0
## Share of screen cells that may morph (non-ramp) or animate ambiently at once.
@export_range(0.0, 1.0) var max_morph_area: float = 0.25
@export_range(0.0, 1.0) var max_ambient_area: float = 0.15
## Largest full-screen brightness change per event and highest flash repeat rate.
@export var max_flash_delta: float = 0.4
@export var max_flash_hz: float = 1.0
## Optional per-cell luminance smoothing time constant (seconds), for a later stateful buffer.
@export var l_smoothing_tau: float = 0.12

@export_group("Erosion")
## Shapes the identity glyph morphs toward as erosion rises (a seeded pick, never a random swap).
@export var corrupt_glyphs: String = "#%&@§?~"
## The target may change at most this often, and only through a morph of this duration.
@export var erosion_retarget_min: float = 1.5
@export var erosion_retarget_morph: float = 0.9
## Colour the glyph shifts to at full erosion; the glow shifts to the same hue.
@export var erosion_tint: Color = Color("#B44DFF")
## Slow domain warp of the glyph: amplitude (share of the glyph size at full erosion) and frequency.
@export_range(0.0, 0.3) var erosion_warp_amp: float = 0.06
@export_range(0.0, 0.5) var erosion_warp_hz: float = 0.35
## Above this erosion one fragment is shed every erosion_shed_interval and drifts off.
@export_range(0.0, 1.0) var erosion_shed_threshold: float = 0.5
@export var erosion_shed_interval: float = 0.8
@export var erosion_shed_duration: float = 1.0
## Shed fragments drift this far, in glyph heights.
@export var erosion_shed_drift: float = 0.9

@export_group("Death")
## The identity glyph splits into this many fragments (angular slices). Each flies `death_spread_cells`
## map cells outward (ease-out) and morphs identity -> abstract -> empty over `death_duration`.
@export var death_fragments: int = 10
@export var death_spread_cells: float = 1.5
## Seconds of the fragment flight and morph; keep at or below RunConfig.restart_delay.
@export var death_duration: float = 1.2
## Angular overlap (radians) between neighbouring slices, so no seam shows, and the progress at which a
## fragment starts fading out.
@export var slice_overlap: float = 0.05
@export_range(0.0, 1.0) var fragment_fade_start: float = 0.55
## Shapes the fragments morph into on their way out.
@export var fragment_glyphs: String = "·,`"
## Fragment glyph size as a fraction of the identity glyph size.
@export_range(0.1, 1.0) var fragment_size_ratio: float = 0.7
## The world dims to this brightness factor over death_dim_time.
@export_range(0.0, 1.0) var death_world_dim: float = 0.4
@export var death_dim_time: float = 0.8
## Spikes only: one soft brightening (brightness factor 1 + this), rising then decaying. No strobe.
@export_range(0.0, 0.4) var spike_death_flash: float = 0.3
@export var flash_rise: float = 0.15
@export var flash_decay: float = 0.4
## Run end cause that gets the spike brightening.
@export var flash_cause: StringName = &"spikes"
