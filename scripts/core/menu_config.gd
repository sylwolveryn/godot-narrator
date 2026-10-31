class_name MenuConfig
extends Resource
## Tuning of the in-world menu (task-018): when it unlocks, which items it offers, how the surroundings fold into it and
## how it looks. Instance: resources/config/menu_config.tres (items in resources/config/menu_items/), built by tools/build_menu.gd.

@export_group("Unlock")
## The menu unlocks when PersistentProgress.death_count reaches this ("after the third death").
@export var menu_unlock_deaths: int = 3
## Items in display order. Items that need the entity are left out until it is unlocked.
@export var items: Array[MenuItemDef] = []

@export_group("Input actions")
## InputMap action names (defined by tools/build_input_map.gd).
@export var action_toggle: StringName = &"menu_toggle"
@export var action_up: StringName = &"menu_up"
@export var action_down: StringName = &"menu_down"
@export var action_confirm: StringName = &"menu_confirm"

@export_group("Layout")
## Fonts the menu glyphs are rasterised with (first available).
@export var font_names: PackedStringArray = PackedStringArray(["Consolas", "Lucida Console", "Courier New", "monospace"])
## Font weight of menu glyphs.
@export_range(100, 900) var font_weight: int = 700
## Height of the menu centre above the player glyph, on the screen (world units).
@export var centre_up: float = 3.7
## Horizontal advance of one letter and height of its tile (world units).
@export var advance: float = 0.5
@export var glyph_size: float = 0.82
## Vertical distance between item rows.
@export var row_height: float = 1.0
## Space between the longest label and the frame (x), and between the outer rows and the frame (y).
@export var padding: Vector2 = Vector2(1.5, 0.75)
## Distance from the ends of a label to its pointer glyphs.
@export var marker_gap: float = 0.8
## Distance between frame glyphs and their size.
@export var frame_step: float = 0.46
@export var frame_size: float = 0.5
## Glyphs of the frame: corner, horizontal, vertical.
@export var frame_corner: String = "+"
@export var frame_horizontal: String = "-"
@export var frame_vertical: String = "|"
## Glyphs that point at the selected item (left, right).
@export var marker_left: String = ">"
@export var marker_right: String = "<"
## Fraction of a quad the glyph covers; the rest holds the dark backing outline.
@export_range(0.2, 1.0) var glyph_fill: float = 0.8
@export_range(0.0, 0.2) var outline_width: float = 0.08
@export var outline_color: Color = Color(0.01, 0.005, 0.03, 1.0)
## Dark panel behind the menu: opacity and soft edge.
@export_range(0.0, 1.0) var panel_alpha: float = 0.55
@export var panel_color: Color = Color(0.01, 0.01, 0.03, 1.0)

@export_group("Colours")
@export var item_color: Color = Color(0.62, 0.78, 0.95)
@export var selected_color: Color = Color(1.0, 0.93, 0.62)
@export var frame_color: Color = Color(0.78, 0.62, 0.32)
## Warm glow behind the selected item.
@export var glow_color: Color = Color(1.0, 0.62, 0.22)
@export_range(0.0, 2.0) var glow_strength: float = 0.8
## Colour the glyphs have while they are still part of the floor and the walls.
@export var floor_source_color: Color = Color(0.36, 0.40, 0.62)
@export var wall_source_color: Color = Color(0.45, 0.58, 0.9)

@export_group("Surroundings")
## Glyphs the menu borrows from the floor and from the walls, and the share taken from walls.
@export var floor_source_glyphs: String = ".,:;'`"
@export var wall_source_glyphs: String = "#=%"
@export_range(0.0, 1.0) var wall_share: float = 0.3
## They are taken from this far around the player (world units).
@export var source_radius: float = 2.8
## The floor and walls around the player dim to this fraction while their glyphs are away, within this radius.
@export_range(0.0, 1.0) var lift_dim: float = 0.55
@export var lift_radius: float = 3.6

@export_group("Motion")
## Seconds one glyph flies for, stagger per glyph in reading order, extra random delay.
@export var open_duration: float = 0.7
@export var open_stagger: float = 0.012
@export var open_jitter: float = 0.18
## Seconds the glyphs take to fly back, plus a random extra delay up to return_jitter.
@export var return_duration: float = 0.65
@export var return_jitter: float = 0.4
## Height of the arc a flying glyph makes (world units) plus extra per unit of distance.
@export var arc_height: float = 0.8
@export var arc_per_distance: float = 0.1
## Whole spins in flight (1 up to about this many, random direction, so each lands upright).
@export var spin_turns: float = 2.0
## Scale pop in flight (fraction), size at take-off (fraction of the final size), brightness flash.
@export var pop: float = 0.4
@export var start_size_ratio: float = 0.45
@export var flash: float = 0.15
## Overshoot of the landing ease (0 = none).
@export var overshoot: float = 1.2
## Slow bob of the settled menu (world units, radians per second).
@export var bob_amount: float = 0.02
@export var bob_speed: float = 2.0
## Seconds the highlight takes to move from one item to the next, and how much the selected letters swell.
@export var select_duration: float = 0.18
@export_range(0.0, 0.5) var select_swell: float = 0.12
## How long the dim of the floor takes to open and to close (seconds).
@export var lift_in: float = 0.5
@export var lift_out: float = 0.7


## Upper bound in seconds from closing until every glyph is back (the view hides itself after this).
func return_total() -> float:
	return return_duration * 1.2 + return_jitter + 0.1
