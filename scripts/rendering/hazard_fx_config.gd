class_name HazardFxConfig
extends Resource
## Ambient animation of hazards (docs/visual_direction.md sections 5 and 6): spikes pulse and
## corruption breathes. Everything is slow (at or below 0.5 Hz) and derived from time plus static
## world noise. Instance: resources/config/hazard_fx_config.tres.

@export_group("Spikes")
@export var spike_pulse_hz: float = 0.4
@export_range(0.0, 0.25) var spike_pulse_amp: float = 0.15
@export_range(0.0, 1.0) var spike_base_l: float = 0.75

@export_group("Corruption")
## Glyph warp amplitude in cells and the period of the flow noise in seconds.
@export var corrupt_warp_amp: float = 0.35
@export var corrupt_warp_period: float = 3.2
## Violet <-> magenta hue slide frequency.
@export var corrupt_hue_hz: float = 0.3
## Luminance breathing amplitude and frequency.
@export_range(0.0, 0.25) var corrupt_l_amp: float = 0.12
@export var corrupt_l_hz: float = 0.25
@export_range(0.0, 1.0) var corrupt_base_l: float = 0.6
## Swirling field (task-026): feature frequency per world unit, domain-warp strength, flow speed as a
## share of corrupt_warp_period, and the ramp position of the darkest strands.
@export var corrupt_swirl_scale: float = 0.9
@export var corrupt_swirl_warp: float = 2.0
@export_range(0.0, 1.0) var corrupt_swirl_flow: float = 0.4
@export_range(0.0, 1.0) var corrupt_swirl_floor: float = 0.1
## Static per-cell ramp jitter inside the swirl (breaks up horizontal banding).
@export_range(0.0, 1.0) var corrupt_swirl_jitter: float = 0.3
## Share of the corruption's neighbour-cell bloom that is kept (the rest would fill gaps between strands).
@export_range(0.0, 1.0) var corrupt_bloom_share: float = 0.3
