class_name DisplayConfig
extends Resource
## Screen scaling and window-mode tunables. Every pixel size in the other configs is a
## reference size for `reference_size`; the runtime scale is viewport height / reference height.
## Instance: resources/config/display_config.tres. The fullscreen default itself lives in the
## project setting display/window/size/mode (written by tools/build_project_settings.gd).

## Resolution the pixel values in the other configs were authored for.
@export var reference_size: Vector2i = Vector2i(1920, 1080)
## Window size used when leaving fullscreen.
@export var windowed_size: Vector2i = Vector2i(1280, 720)
## Lower bound of the scale factor, so a tiny window never produces zero-sized glyphs.
@export var min_scale: float = 0.25


## Scale factor for `viewport`: its height relative to the reference height.
func scale_for(viewport: Viewport) -> float:
	var height: float = viewport.get_visible_rect().size.y
	return maxf(height / float(reference_size.y), min_scale)


## `reference_px` scaled by `factor`, rounded to a whole pixel and at least `minimum`.
static func px(reference_px: float, factor: float, minimum: int = 1) -> int:
	return maxi(roundi(reference_px * factor), minimum)
