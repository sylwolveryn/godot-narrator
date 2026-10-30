class_name NarrationBeat
extends Resource
## One line of narration, as data. Instances live in resources/narration/ and are built by
## tools/build_narration.gd from data/narration/m1_beats.json.

enum Trigger { EVENT, TIME }

@export var id: String = ""
@export var text: String = ""
@export var trigger: Trigger = Trigger.EVENT
## EVENT beats: the event name (see NarrationEvents).
@export var event: StringName = &""
## TIME beats: seconds after run_started.
@export var delay: float = 0.0
## Eligible from this run on (1 = the very first run).
@export var min_run: int = 1
## Eligible up to and including this run; -1 = no upper bound.
@export var max_run: int = -1
## Eligible once the character has died at least this many times.
@export var min_deaths: int = 0
## When true the beat is played at most once ever (recorded in PersistentProgress.heard_beats).
@export var once: bool = true
## Sound mood played with the beat (a NarrationMood id in NarratorConfig).
@export var mood: StringName = &"hum"
## Origins the line hints at (M2 uses them to rule origins out).
@export var origin_tags: PackedStringArray = PackedStringArray()
## Position in the beat table; breaks ties inside an event ladder.
@export var order: int = 0
