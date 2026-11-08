class_name NarrationEvents
extends RefCounted
## Names of the narration events carried by SignalBus.narration_event (plus the ones the narrator derives itself).
## The values are the ids of the SpacetimeDB lookup table `event_def` (task-049); beats reference them in their
## `event` field and the narration files are named after them (narration/event/<EVENT>_<LANGUAGE>.json).

const RUN_STARTED: StringName = &"RUN_STARTED"
const FIRST_MOVE: StringName = &"FIRST_MOVE"
## Stillness ladder: NarratorConfig.idle_seconds / idle_mid_seconds / idle_long_seconds without moving.
const IDLE_FOR_SHORT: StringName = &"IDLE_FOR_SHORT"
const IDLE_FOR_MID: StringName = &"IDLE_FOR_MID"
const IDLE_FOR_LONG: StringName = &"IDLE_FOR_LONG"
## Kept for older callers: the first idle step.
const IDLE: StringName = IDLE_FOR_SHORT
const WALL_REVEALED: StringName = &"WALL_REVEALED"
const ITEM_REVEALED: StringName = &"ITEM_REVEALED"
const SPIKES_REVEALED: StringName = &"SPIKES_REVEALED"
const CORRUPTION_ENTERED: StringName = &"CORRUPTION_ENTERED"
const EROSION_HIGH: StringName = &"EROSION_HIGH"
## The player bumped into a wall / into something else that blocks (void edge, object) / touched spikes.
const HIT_WALL: StringName = &"HIT_WALL"
const HIT_UNKNOWN: StringName = &"HIT_UNKNOWN"
const HIT_SPIKES: StringName = &"HIT_SPIKES"
## Any death whose cause has no own event, and the per-cause deaths.
const DEATH: StringName = &"DEATH"
const DEATH_BY_SPIKES: StringName = &"DEATH_BY_SPIKES"
const DEATH_BY_CORRUPTION: StringName = &"DEATH_BY_CORRUPTION"
const DIED_SPIKES: StringName = DEATH_BY_SPIKES
const DIED_CORRUPTION: StringName = DEATH_BY_CORRUPTION
## A chosen entity form switch (animated entity_form_changed; task-042): the specific direction is offered first,
## TRANSFORMED is its fallback (NarratorConfig.event_fallbacks), so beats can answer any switch.
const TRANSFORMED_TO_ONE: StringName = &"TRANSFORMED_TO_ONE"
const TRANSFORMED_TO_MANY: StringName = &"TRANSFORMED_TO_MANY"
const TRANSFORMED: StringName = &"TRANSFORMED"
const ENTITY_FORM_CHANGED: StringName = TRANSFORMED
## A nature was struck / came back (SignalBus.origin_struck / origin_recanted). The narrator offers them with the
## nature id as the event parameter (NarrationBeat.event_param).
const ORIGIN_STRUCK: StringName = &"ORIGIN_STRUCK"
const ORIGIN_RECANTED: StringName = &"ORIGIN_RECANTED"
## The first move of a run in which sprint (Left Shift) is available (task-063).
const SPRINT_UNLOCKED: StringName = &"SPRINT_UNLOCKED"
## Dirt walls (task-070): every eaten dirt cell, and the eaten counter reaching its next random milestone.
const WALL_EATEN: StringName = &"WALL_EATEN"
const WALLS_DEVOURED: StringName = &"WALLS_DEVOURED"
## Enemies (task-075): the run ended by touching an enemy (every enemy_<kind> cause).
const DEATH_BY_ENEMY: StringName = &"DEATH_BY_ENEMY"
## Enemy remains (task-076): a black hole formed (a destroyed hunter), a diamond was picked up.
const BLACK_HOLE_FORMED: StringName = &"BLACK_HOLE_FORMED"
const DIAMOND_FOUND: StringName = &"DIAMOND_FOUND"
## Priority key used for TIME beats (they have no event name).
const TIME: StringName = &"TIME"
