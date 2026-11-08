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
## Emitted by the player every time it enters another map cell during a run (the track record counts steps).
signal player_stepped(cell: Vector2i)
## Emitted by the narrator when a beat starts displaying; SaveService records it as heard.
signal beat_heard(beat_id: String)
## Emitted by EntityProgression the moment the multi-glyph entity unlocks (the run that ends at the unlock threshold).
signal entity_unlocked
## Emitted by EntityProgression when the grow moment starts: the single glyph is about to grow into the entity (a hook for the narrator).
signal entity_grown
## Emitted by EntityProgression when the active form is set (grown after unlock, restored on every run start, or switched).
## `animate` is true when the change should be played as a morph, false when the form should simply appear.
signal entity_form_changed(form: StringName, animate: bool)
## Emitted by MenuController the moment the in-world menu unlocks (the death that reaches MenuConfig.menu_unlock_deaths).
signal menu_unlocked
## Emitted by MenuController when the menu opens: the labels of the offered items (in order) and the selected index.
## The world keeps running; presentation builds the menu from the surroundings.
signal menu_opened(labels: PackedStringArray, selected: int)
## Emitted by MenuController when the menu closes (toggle, an item that closes it, or the run ending).
signal menu_closed
## Emitted by MenuController when the "remember" item is confirmed (task-043): the ledger as a row, one entry per
## hypothesis: {id: StringName, sigil: String, state: StringName (MenuController.LEDGER_*)}. Going back re-emits menu_opened.
signal menu_ledger_shown(entries: Array)
## Emitted by MenuController when the selection moves to item `index`.
signal menu_selection_changed(index: int)
## Emitted by the menu presentation when the pointer hovers (activate = false) or clicks (activate = true) item `index`.
signal menu_item_pointed(index: int, activate: bool)
## Emitted by MenuController when an item was confirmed: `action` is a MenuItemDef action (e.g. switch_form); the data layer applies it.
signal menu_action_requested(action: StringName)
## Emitted by PushableObjects when the grown entity pushes a small object one cell: `object_id` is its index in the map,
## `form` the pushing entity's form (EntityForm). Hook for the future alien trial; carries no narration.
signal object_moved(object_id: int, from_cell: Vector2i, to_cell: Vector2i, form: StringName)

## Origin rule-out system (task-039). Emitted by the trial monitor when an armed trial passed; OriginLedger answers.
signal origin_trial_passed(id: StringName)
## Emitted by the narrator when a CLAIM beat was heard; OriginLedger arms that nature's trial.
signal origin_claim_heard(id: StringName)
## Emitted by OriginLedger when a nature was struck (ruled out).
signal origin_struck(id: StringName)
## Emitted by OriginLedger when a struck nature came back (recanted).
signal origin_recanted(id: StringName)
## Emitted by OriginLedger after every change: the natures alive and the natures struck (oldest strike first).
signal origin_ledger_changed(alive: PackedStringArray, struck: PackedStringArray)

## Glyph storm (task-030). Anyone may ask for a storm: the glyphs of the floor and walls within `radius` of `centre` (world
## position) lift off, swirl for `duration` seconds and settle. `radius` <= 0 / `duration` <= 0 use the StormConfig defaults,
## `tint` with alpha 0 uses the default tint. The origin ledger's strike already starts one by itself (origin_struck).
signal glyph_storm_requested(centre: Vector3, radius: float, duration: float, tint: Color)
