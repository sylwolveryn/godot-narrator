class_name NarrationMood
extends Resource
## Recipe for one procedurally synthesised ambient sound (no audio assets exist).
## The signal is a sine sweeping freq_start -> freq_end, mixed with an overtone and noise,
## shaped by an attack/release envelope and optionally gated into pulses.

@export var id: StringName = &""
@export var duration: float = 2.0
@export var freq_start: float = 110.0
@export var freq_end: float = 110.0
## Overtone frequency as a ratio of the base and its level (0 = none).
@export var overtone_ratio: float = 1.5
@export_range(0.0, 1.0) var overtone_level: float = 0.0
## Level of white noise mixed in (1 with tone_level 0 = pure noise).
@export_range(0.0, 1.0) var noise_level: float = 0.0
@export_range(0.0, 1.0) var tone_level: float = 1.0
@export var attack: float = 0.3
@export var release: float = 0.8
## 0 = continuous. Otherwise the sound is gated into this many beeps.
@export var pulse_count: int = 0
## Seconds between the start of two beeps.
@export var pulse_interval: float = 0.4
## Length of one beep in seconds.
@export var pulse_length: float = 0.18
## For noise: fraction of samples held for crackle (0 = smooth hiss, higher = crackly).
@export_range(0.0, 0.99) var crackle: float = 0.0
## Mood loudness relative to the narrator's sfx volume (dB).
@export var volume_db: float = 0.0
