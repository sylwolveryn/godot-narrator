class_name LargeObjectViews
extends Resource
## Pre-baked view-dependent ASCII art of a large prop (task-101): the prop rendered offline from `count` camera yaws
## (evenly spaced, view 0 = camera yaw 0) at the game's camera pitch, one art + layer mask per view. LargeObjectView
## shows the view nearest to the camera yaw on a camera-facing billboard, so the prop turns with the camera instead of
## being a flat cut-out. Baked by tools/bake_gargoyle_views.gd; never edited by hand.

## Camera pitch the views were rendered at (degrees, negative looks down).
@export var pitch_degrees: float = -35.264
## Art lines per view (rows joined by "\n").
@export var arts: PackedStringArray = PackedStringArray()
## Layer mask per view, same shape as the art (see LargeObjectDef.mask_lines).
@export var masks: PackedStringArray = PackedStringArray()
## World width of one art column for a 1x1 footprint, and the height of one art row (world units, screen plane).
@export var col_width: float = 0.03
@export var row_height: float = 0.06
## Art cell (column, row) where the prop's base centre (footprint centre on the floor) projects, same for every view.
@export var anchor: Vector2 = Vector2.ZERO
## Distance from the base centre to the front of the baked model's base (world units for a 1x1 footprint): the
## billboard is pushed this far towards the camera along the view ray so it never sinks into the floor.
@export var front_depth: float = 0.2


## Number of baked views.
func count() -> int:
	return arts.size()


## View index for a camera yaw in degrees.
func index_for_yaw(yaw_degrees: float) -> int:
	var n: int = count()
	if n == 0:
		return -1
	return posmod(int(round(yaw_degrees / (360.0 / n))), n)


func art_lines(view: int) -> PackedStringArray:
	return arts[view].split("\n")


func mask_lines(view: int) -> PackedStringArray:
	return masks[view].split("\n") if view < masks.size() else PackedStringArray()
