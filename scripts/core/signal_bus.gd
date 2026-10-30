extends Node
## The single global signal bus. Signals only: no state, no logic.
## Emitters live below; managers and presentation connect to these.

## Emitted by RunManager when a new run begins.
signal run_started(run_index: int)
## Emitted by RunManager when the current run ends.
signal run_ended(cause: StringName)
## Emitted by gameplay (e.g. hazards) to ask RunManager to end the current run.
signal run_end_requested(cause: StringName)
## Emitted by RunManager to ask the intro sequence to play. `lite` is true for a restart re-entry.
signal intro_requested(lite: bool)
## Emitted by the intro sequence when it hands off; RunManager answers by starting the run.
signal intro_finished
## Emitted by the player after it has been placed at the map spawn for a new run.
signal player_spawned(world_position: Vector3)
## Emitted by InputDiscovery when the first supported input is used, or the player switches to another supported device.
signal input_scheme_discovered(scheme: StringName)
## Emitted by MapReveal for cells seen for the first time ever on a map (never persisted before).
signal cells_revealed(map_id: StringName, cells: PackedVector2Array)
