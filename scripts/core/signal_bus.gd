extends Node
## The single global signal bus. Signals only: no state, no logic.
## Emitters live below; managers and presentation connect to these.

## Emitted by RunManager when a new run begins.
signal run_started(run_index: int)
## Emitted by RunManager when the current run ends.
signal run_ended(cause: StringName)
## Emitted by gameplay (e.g. hazards) to ask RunManager to end the current run.
signal run_end_requested(cause: StringName)
