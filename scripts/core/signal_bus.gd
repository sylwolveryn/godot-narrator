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
## Emitted by HazardMonitor while the player erodes: `amount` is 0..1 of the threshold, `tint` the hazard's colour.
signal erosion_changed(amount: float, tint: Color)
## Emitted by HazardMonitor just before it requests the run end, so presentation can colour the death.
signal hazard_lethal(cause: StringName, tint: Color)
## Emitted by the systems that own a narration trigger (e.g. first move, first reveal, hazard entry). `event` is a NarrationEvents name.
signal narration_event(event: StringName)
## Emitted by the player when it starts or stops moving during a run.
signal player_motion_changed(moving: bool)
## Emitted by the narrator when a beat starts displaying; SaveService records it as heard.
signal beat_heard(beat_id: String)
## Emitted by EntityProgression the moment the multi-glyph entity unlocks (the run that ends at the unlock threshold).
signal entity_unlocked
## Emitted by EntityProgression when the grow moment starts: the single glyph is about to grow into the entity (a hook for the narrator).
signal entity_grown
## Emitted by EntityProgression when the active form is set (grown after unlock, restored on every run start, or switched).
## `animate` is true when the change should be played as a morph, false when the form should simply appear.
signal entity_form_changed(form: StringName, animate: bool)
