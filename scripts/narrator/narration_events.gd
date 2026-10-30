class_name NarrationEvents
extends RefCounted
## Names of the narration events carried by SignalBus.narration_event (plus the ones the
## narrator derives itself). Beats reference these names in their `event` field.

const RUN_STARTED: StringName = &"run_started"
const FIRST_MOVE: StringName = &"first_move"
const IDLE: StringName = &"idle"
const WALL_REVEALED: StringName = &"wall_revealed"
const ITEM_REVEALED: StringName = &"item_revealed"
const SPIKES_REVEALED: StringName = &"spikes_revealed"
const CORRUPTION_ENTERED: StringName = &"corruption_entered"
const EROSION_HIGH: StringName = &"erosion_high"
const DIED_SPIKES: StringName = &"died_spikes"
const DIED_CORRUPTION: StringName = &"died_corruption"
## Priority key used for TIME beats (they have no event name).
const TIME: StringName = &"time"
