class_name LightConfig
extends Resource
## The player's light (docs/visual_direction.md section 3). Radii are in glyph cells at the
## DisplayConfig reference size, so the pool of light looks the same at every resolution.
## Instance: resources/config/light_config.tres.

## Full brightness inside the inner radius, smoothstep down to light_ambient at the outer one.
@export var light_inner: float = 12.0
@export var light_outer: float = 24.0
## Luminance of lit materials far from the player.
@export_range(0.0, 1.0) var light_ambient: float = 0.12
## How strongly the warm light tint replaces the colour inside the light.
@export_range(0.0, 1.0) var light_tint_strength: float = 0.5
## Warm amber added to the empty background inside the light (0 disables it).
@export_range(0.0, 1.0) var bg_pool_strength: float = 0.22
