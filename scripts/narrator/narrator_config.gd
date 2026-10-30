class_name NarratorConfig
extends Resource
## Tunables for the narrator. Instance: resources/narration/narrator_config.tres
## (built by tools/build_narration.gd, which also fills `beats` and `moods`).

@export var beats: Array[NarrationBeat] = []
@export var moods: Array[NarrationMood] = []

@export_group("Timing (seconds)")
## No movement for this long fires the `idle` event (once per run).
@export var idle_seconds: float = 8.0
## Erosion fraction (0..1 of the lethal threshold) that fires `erosion_high` (once per run).
@export_range(0.0, 1.0) var erosion_high_threshold: float = 0.7
## Fully legible time of a beat, between morph-in and morph-out.
@export var beat_hold_seconds: float = 3.5
## Minimum silence after a beat has dissolved.
@export var beat_gap_seconds: float = 4.0
## A queued beat is dropped after waiting this long.
@export var queue_ttl_seconds: float = 5.0
## Events whose queued beats never expire by TTL (they can only be replaced by a higher class, then they re-queue).
@export var ttl_exempt_events: Array[StringName] = [NarrationEvents.RUN_STARTED]
## Time budgets of the line morphing in and out. The overlay's letter staggers shrink when a long line
## would not fit (the line is fully legible when the hold starts).
@export var morph_in_seconds: float = 1.1
@export var morph_out_seconds: float = 0.9
## How long the current beat dissolves when a death beat preempts it (share of it spent morphing a letter).
@export var preempt_dissolve_seconds: float = 0.3
@export_range(0.1, 1.0) var preempt_morph_share: float = 0.6

@export_group("Priority")
## Event -> class priority (higher wins when triggers are simultaneous or compete for the queue).
@export var event_priority: Dictionary[StringName, int] = {
	NarrationEvents.DIED_SPIKES: 5,
	NarrationEvents.DIED_CORRUPTION: 5,
	NarrationEvents.EROSION_HIGH: 4,
	NarrationEvents.CORRUPTION_ENTERED: 3,
	NarrationEvents.SPIKES_REVEALED: 3,
	NarrationEvents.ITEM_REVEALED: 2,
	NarrationEvents.WALL_REVEALED: 2,
	NarrationEvents.RUN_STARTED: 1,
	NarrationEvents.FIRST_MOVE: 1,
	NarrationEvents.IDLE: 0,
	NarrationEvents.TIME: 0,
}
## Priority at or above which a beat preempts whatever is on screen.
@export var preempt_priority: int = 5
## Run end cause -> death event.
@export var death_events: Dictionary[StringName, StringName] = {
	&"spikes": NarrationEvents.DIED_SPIKES,
	&"corruption": NarrationEvents.DIED_CORRUPTION,
}

@export_group("Presentation")
## Canvas layer of the narration text (above the ASCII shader, and above the intro veil).
@export var overlay_layer: int = 25
## Text size in reference pixels (scaled with the window height); letters are SDF quads from the shared atlas.
@export var font_size: int = 60
@export var text_color: Color = Color("#EAF2FF")
## Dark rim around the letters (SDF units, about 8 atlas pixels per unit) that keeps them legible over glyphs.
@export var outline_color: Color = Color(0.012, 0.016, 0.035, 0.95)
@export var outline_width: float = 0.25
## Letter glow strength and SDF falloff, and the quad margin (share of the glyph size) for the halo.
@export var glow_strength: float = 0.55
@export var glow_radius: float = 0.35
@export var glow_pad: float = 0.4
## Glow tint per mood (docs/visual_direction.md section 2); an unknown mood glows in the text colour.
@export var mood_tints: Dictionary[StringName, Color] = {
	&"hum": Color("#FFC98A"),
	&"chime": Color("#BFF6FF"),
	&"static": Color("#E07BFF"),
	&"low_drone": Color("#FF6A4D"),
	&"pulse": Color("#7DFFB0"),
}
## Vertical position of the text line as a fraction of the screen height (lower third).
@export_range(0.0, 1.0) var vertical_anchor: float = 0.82
## Largest width of the text block in pixels at the reference resolution (scaled at runtime).
@export var max_text_width: float = 1600.0
## Fraction of the screen width kept free on each side (applies when the window is narrower than max_text_width).
@export_range(0.0, 0.4) var side_margin: float = 0.08
## Line height as a multiple of an atlas tile height.
@export var line_spacing: float = 1.0

@export_group("Letter morph")
## Each letter starts as one of these abstract shapes (plus the circle SDF), morphs into the letter,
## rises `letter_rise_px` (reference pixels) and starts `letter_stagger_in` after the previous one.
@export var abstract_glyphs: String = "·-~°"
@export var letter_morph_in: float = 0.35
@export var letter_stagger_in: float = 0.03
@export var letter_rise_px: float = 4.0
## Morph out: letter -> abstract -> transparent, staggered left to right.
@export var letter_morph_out: float = 0.5
@export var letter_stagger_out: float = 0.02
## Opacity of a letter at the start of its morph in (it grows to 1 over the first share of the morph).
@export_range(0.0, 1.0) var abstract_alpha_share: float = 0.4

@export_group("Audio")
@export var sfx_volume_db: float = -14.0
@export var sfx_sample_rate: int = 22050
@export var sfx_bus: StringName = &"Master"
