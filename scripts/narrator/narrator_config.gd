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
@export var morph_in_seconds: float = 1.1
@export var morph_out_seconds: float = 0.9
## How long the current beat dissolves when a death beat preempts it.
@export var preempt_dissolve_seconds: float = 0.3

@export_group("Priority")
## Event -> class priority (higher wins when triggers are simultaneous or compete for the queue).
@export var event_priority: Dictionary[StringName, int] = {
	NarrationEvents.DIED_SPIKES: 5,
	NarrationEvents.DIED_CORRUPTION: 5,
	NarrationEvents.EROSION_HIGH: 4,
	NarrationEvents.CORRUPTION_ENTERED: 3,
	NarrationEvents.ENTITY_FORM_CHANGED: 3,
	NarrationEvents.SPIKES_REVEALED: 3,
	NarrationEvents.ITEM_REVEALED: 2,
	NarrationEvents.WALL_REVEALED: 2,
	NarrationEvents.RUN_STARTED: 1,
	NarrationEvents.FIRST_MOVE: 1,
	NarrationEvents.IDLE: 0,
	NarrationEvents.TIME: 0,
}
## Reactive events (the death-beat class of docs/narration_origin.md, without the preempt): their beats answer
## something the player just did. They never go through the one-slot queue, so the queue TTL cannot drop them and
## nothing replaces them; they wait in a FIFO and start as soon as no beat is showing (the silence gap does not
## hold them back). They start before any queued ordinary beat and are accepted outside a run too.
@export var reactive_events: Array[StringName] = [NarrationEvents.ORIGIN_STRUCK, NarrationEvents.ORIGIN_RECANTED]
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
@export var font_names: PackedStringArray = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "monospace"])
@export var font_size: int = 60
@export var text_color: Color = Color("#EAF2FF")
@export var outline_color: Color = Color(0.012, 0.016, 0.035, 0.95)
@export var outline_size: int = 16
## Vertical position of the text line as a fraction of the screen height (lower third).
@export_range(0.0, 1.0) var vertical_anchor: float = 0.82
## Largest width of the text block in pixels at the reference resolution (scaled at runtime).
@export var max_text_width: float = 1600.0
## Fraction of the screen width kept free on each side (applies when the window is narrower than max_text_width).
@export_range(0.0, 0.4) var side_margin: float = 0.08

@export_group("Letter motion")
## Letters fly in from scattered spots at most this far (reference px, scaled at runtime) and settle with an ease-out.
@export var assemble_scatter_px: float = 150.0
## Letters leave towards scattered spots this far, drifting up by `disperse_rise_px`.
@export var disperse_scatter_px: float = 90.0
@export var disperse_rise_px: float = 40.0
## Fraction of the morph time spent staggering the letters' start (0 = all start together; the rest is each letter's flight).
@export_range(0.0, 0.8) var stagger_fraction: float = 0.55
## Soft glow quad behind each letter: size as a multiple of the font size, and strength (0 = off).
@export var glow_size_factor: float = 1.9
@export_range(0.0, 1.0) var glow_strength: float = 0.45
## Extra glow while a letter is in flight (it settles to `glow_strength`).
@export_range(0.0, 1.0) var glow_flight_boost: float = 0.4
## Glow tint per beat mood (same ids as the sound moods).
@export var mood_glow_colors: Dictionary[StringName, Color] = {
	&"hum": Color("#FFC98A"),
	&"chime": Color("#BFF6FF"),
	&"static": Color("#E07BFF"),
	&"low_drone": Color("#FF6A4D"),
	&"pulse": Color("#7DFFB0"),
}
@export var default_glow_color: Color = Color("#FFC98A")

@export_group("Doubt")
## A doubt line (all its supported natures struck, see Narrator.current_doubt) lets a share of its letters
## (OriginConfig.doubt_scramble) drift calmly instead of settling: they sway around their place by this many reference
## px and dip in brightness. The letters themselves never change.
@export var doubt_drift_px: float = 5.0
## Sway / dip speed in Hz, at most 0.5 (docs/visual_direction.md flicker limits; per-letter speed varies by up to 20%).
@export_range(0.05, 0.5) var doubt_hz: float = 0.4
## Brightness of an unsettled letter swings between 1 and 1 minus this (a swing of half of it, within the 0.25 limit).
@export_range(0.0, 0.5) var doubt_alpha_dip: float = 0.4

@export_group("Audio")
@export var sfx_volume_db: float = -14.0
@export var sfx_sample_rate: int = 22050
@export var sfx_bus: StringName = &"Master"
