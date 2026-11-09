class_name NarratorConfig
extends Resource
## Tunables for the narrator. Instance: resources/narration/narrator_config.tres
## (built by tools/build_narration.gd, which also fills `beats` and `moods`).

@export var beats: Array[NarrationBeat] = []
@export var moods: Array[NarrationMood] = []

@export_group("Timing (seconds)")
## No movement for this long fires IDLE_FOR_SHORT, then IDLE_FOR_MID and IDLE_FOR_LONG (each at most once per run;
## the stillness clock restarts whenever the player moves).
@export var idle_seconds: float = 8.0
@export var idle_mid_seconds: float = 20.0
@export var idle_long_seconds: float = 45.0
## Erosion fraction (0..1 of the lethal threshold) that fires `erosion_high` (once per run).
@export_range(0.0, 1.0) var erosion_high_threshold: float = 0.7
## Fully legible time of a beat, between morph-in and morph-out.
@export var beat_hold_seconds: float = 3.5
## Minimum silence after a beat has dissolved.
@export var beat_gap_seconds: float = 4.0
## A queued beat is dropped after waiting this long.
@export var queue_ttl_seconds: float = 5.0
## Events whose queued beats never expire by TTL (they can only be replaced by a higher class, then they re-queue).
@export var ttl_exempt_events: Array[StringName] = [NarrationEvents.RUN_STARTED, NarrationEvents.SPRINT_UNLOCKED, NarrationEvents.WALLS_DEVOURED]
@export var morph_in_seconds: float = 1.1
@export var morph_out_seconds: float = 0.9
## How long the current beat dissolves when a death beat preempts it.
@export var preempt_dissolve_seconds: float = 0.3

@export_group("Repeats (task-087)")
## Story lines of events repeat: a line never heard always plays (it waits for its turn, it is never dropped); a heard
## line plays again only when a roll passes: repeat_chances[n - 1] after n hearings, repeat_chance_min after the list.
## Origin lines (claim / broken / recant) and timed lines keep their once-only rules.
@export var repeat_chances: PackedFloat32Array = PackedFloat32Array([0.8, 0.6, 0.5, 0.35, 0.2, 0.12, 0.06, 0.03, 0.03,
		0.03, 0.03, 0.03, 0.02, 0.02, 0.02, 0.02, 0.02])
@export_range(0.0, 1.0) var repeat_chance_min: float = 0.01

@export_group("Priority")
## Event -> class priority (higher wins when triggers are simultaneous or compete for the queue).
@export var event_priority: Dictionary[StringName, int] = {
	NarrationEvents.DEATH: 5,
	NarrationEvents.DEATH_BY_SPIKES: 5,
	NarrationEvents.DEATH_BY_CORRUPTION: 5,
	NarrationEvents.DEATH_BY_ENEMY: 5,
	NarrationEvents.EROSION_HIGH: 4,
	NarrationEvents.CORRUPTION_ENTERED: 3,
	NarrationEvents.TRANSFORMED: 3,
	NarrationEvents.TRANSFORMED_TO_ONE: 3,
	NarrationEvents.TRANSFORMED_TO_MANY: 3,
	NarrationEvents.HIT_SPIKES: 3,
	NarrationEvents.SPIKES_REVEALED: 3,
	NarrationEvents.ITEM_REVEALED: 2,
	NarrationEvents.WALL_REVEALED: 2,
	NarrationEvents.RUN_STARTED: 1,
	NarrationEvents.FIRST_MOVE: 1,
	NarrationEvents.SPRINT_UNLOCKED: 2,
	NarrationEvents.HIT_WALL: 1,
	NarrationEvents.HIT_UNKNOWN: 1,
	NarrationEvents.WALL_EATEN: 1,
	NarrationEvents.WALLS_DEVOURED: 2,
	NarrationEvents.BLACK_HOLE_FORMED: 2,
	NarrationEvents.DIAMOND_FOUND: 1,
	NarrationEvents.IDLE_FOR_SHORT: 0,
	NarrationEvents.IDLE_FOR_MID: 0,
	NarrationEvents.IDLE_FOR_LONG: 0,
	NarrationEvents.TIME: 0,
}
## Reactive events (the death-beat class of docs/narration_origin.md, without the preempt): their beats answer
## something the player just did. They never go through the one-slot queue, so the queue TTL cannot drop them and
## nothing replaces them; they wait in a FIFO and start as soon as no beat is showing (the silence gap does not
## hold them back). They start before any queued ordinary beat and are accepted outside a run too.
@export var reactive_events: Array[StringName] = [NarrationEvents.ORIGIN_STRUCK, NarrationEvents.ORIGIN_RECANTED]
## Events whose equally ranked eligible beats (same layer and min_run) are picked at random (Narrator.rng) instead of by
## table order, e.g. the WALLS_DEVOURED variants.
@export var random_pick_events: Array[StringName] = [NarrationEvents.WALLS_DEVOURED]
## Priority at or above which a beat preempts whatever is on screen.
@export var preempt_priority: int = 5
## Run end cause -> death event.
@export var death_events: Dictionary[StringName, StringName] = {
	&"spikes": NarrationEvents.DEATH_BY_SPIKES,
	&"corruption": NarrationEvents.DEATH_BY_CORRUPTION,
	# Task-075: EnemyDef.end_cause() of every enemy kind.
	&"enemy_crawler": NarrationEvents.DEATH_BY_ENEMY,
	&"enemy_hunter": NarrationEvents.DEATH_BY_ENEMY,
	&"enemy_wanderer": NarrationEvents.DEATH_BY_ENEMY,
}
## Death event for a run end cause missing from `death_events`.
@export var default_death_event: StringName = NarrationEvents.DEATH
## Event -> event whose beats answer it when it has no eligible beat of its own (a specific transformation falls back
## to any transformation, a specific death to the plain DEATH).
@export var event_fallbacks: Dictionary[StringName, StringName] = {
	NarrationEvents.TRANSFORMED_TO_ONE: NarrationEvents.TRANSFORMED,
	NarrationEvents.TRANSFORMED_TO_MANY: NarrationEvents.TRANSFORMED,
	NarrationEvents.DEATH_BY_SPIKES: NarrationEvents.DEATH,
	NarrationEvents.DEATH_BY_CORRUPTION: NarrationEvents.DEATH,
	NarrationEvents.DEATH_BY_ENEMY: NarrationEvents.DEATH,
}

## Chance that a line heard `hearings` times plays again (1 for a line never heard).
func repeat_chance(hearings: int) -> float:
	if hearings <= 0:
		return 1.0
	if hearings - 1 < repeat_chances.size():
		return maxf(repeat_chances[hearings - 1], repeat_chance_min)
	return repeat_chance_min


@export_group("Presentation")
## Canvas layer of the narration text (above the ASCII shader, and above the intro veil).
@export var overlay_layer: int = 25
@export var font_names: PackedStringArray = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "monospace"])
@export var font_size: int = 60
## Fonts tried, in order, for characters the main font lacks (CJK and emoji stand-ins of the obfuscation).
@export var fallback_font_names: PackedStringArray = PackedStringArray(["Yu Gothic", "MS Gothic", "Microsoft YaHei", "Segoe UI Symbol", "Segoe UI Emoji"])
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

@export_group("Layers")
## World lines (task-062): vibrant green / purple, glitchy. Letter colour sweeps between the two, a green and a purple
## ghost split sideways, and on every glitch tick a share of the letters jumps and swaps to a glitch glyph.
@export var world_colors: PackedColorArray = PackedColorArray([Color("#39ff88"), Color("#c04dff")])
## Colour sweeps per second, ghost split (reference px), glitch ticks per second, share of letters per tick, jump (px).
@export var world_wave_hz: float = 0.35
## Phase step of the colour sweep from one letter to the next (radians), so even a short word shows both colours.
@export var world_letter_phase: float = 1.3
@export var world_split_px: float = 4.0
@export var world_ghost_alpha: float = 0.7
@export var world_glitch_hz: float = 7.0
@export_range(0.0, 1.0) var world_glitch_share: float = 0.12
## Share kept at full understanding (the glitch share falls from world_glitch_share at 0% to this at 100%).
@export_range(0.0, 1.0) var world_glitch_min_share: float = 0.03
@export var world_jitter_px: float = 6.0
@export var glitch_glyphs: String = "#%&@$*+=?!/|<>~^01"
## Own lines: the character's own glyph colour (PlayerConfig.glyph_color when the overlay has it, else this). Words the
## character does not understand (share = 1 - understanding of the narration language) keep switching between the
## real word and a scrambled one; a few letters glitch lightly even at full understanding.
@export var own_text_color: Color = Color("#FFF6E6")
@export var own_glow_color: Color = Color("#FFD9A0")
@export var own_scramble_glyphs: String = "ΔΞΣΨΩλψξζ¤§#%"
## Word switches per second (each broken word has its own phase), light glitch ticks per second and share per tick.
@export var own_switch_hz: float = 1.2
@export var own_glitch_hz: float = 5.0
@export_range(0.0, 1.0) var own_glitch_share: float = 0.05
## Narrator lines keep text_color and the mood glow, pulled towards a gloomy blue by narrator_glow_tint.
@export var narrator_glow_color: Color = Color("#5B8CFF")
@export_range(0.0, 1.0) var narrator_glow_tint: float = 0.55

@export_group("Obfuscation")
## Narrator and world lines (never own lines) by understanding of the selected language (task-067). Every character has
## a threshold between obf_found_min and obf_found_max (hashed from the character, case-insensitive): from that
## understanding on it is always shown right, in every word. Below that it is a stand-in:
##   understanding < obf_spin_start: a stable stand-in from obf_static_glyphs (the first obfuscated version);
##   < obf_near_start: it spins through obf_wild_glyphs (symbols, CJK, emoji);
##   above: it spins through characters near the right one (distance shrinking from obf_near_max_dist), showing the
##   right one more and more often as the threshold comes closer.
@export_range(0.0, 1.0) var obf_found_min: float = 0.45
@export_range(0.0, 1.0) var obf_found_max: float = 0.92
@export_range(0.0, 1.0) var obf_spin_start: float = 0.10
@export_range(0.0, 1.0) var obf_near_start: float = 0.30
## Stand-in changes per second while spinning.
@export var obf_spin_hz: float = 6.0
@export var obf_static_glyphs: String = "őŐűŰøØ.¤§þÞðÐ"
@export var obf_wild_glyphs: String = "HXxó+ˇ3{8}#@%&¥ж字書夢光闇の気ア◊☼♠✦✧🌀👁🔥💀"
## Code point distance of the near stand-ins at obf_near_start (shrinks to 1 at the threshold).
@export var obf_near_max_dist: int = 12
## Words with unresolved characters pulse: a slow wave runs along them (reference px, Hz, phase per letter, alpha dip).
@export var obf_wave_px: float = 6.0
@export var obf_wave_hz: float = 0.6
@export var obf_wave_letter_phase: float = 0.6
@export_range(0.0, 1.0) var obf_wave_alpha: float = 0.25

@export_group("Audio")
@export var sfx_volume_db: float = -14.0
@export var sfx_sample_rate: int = 22050
@export var sfx_bus: StringName = &"Master"
