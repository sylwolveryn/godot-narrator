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
## Emitted by DevBridge when the god launcher asks the running game to reveal the whole current map (MapReveal answers).
signal dev_reveal_map_requested
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

## Language understanding (task-065). Emitted by LanguageProgress (the only writer) whenever the understanding of the
## selected language changes, and right after a selection or a load: `understanding` is 0..1. Presentation (world
## clarity, player glyph, narration obfuscation) and the narration library follow it.
signal language_understanding_changed(language: StringName, understanding: float)
## Emitted by LanguageProgress when the selected (narration) language changes, and once after the save is loaded.
signal language_selected(language: StringName)
## Emitted by LanguageProgress when a new language becomes available (at 1%).
signal language_unlocked(language: StringName)
## Emitted by MenuController right before it shows the Language list; LanguageProgress may unlock the next language
## (and start a glyph storm) so the list already contains it.
signal language_list_requested
## Emitted by MenuController when a language was confirmed in the Language list; LanguageProgress applies it.
signal language_select_requested(language: StringName)


## Teleports (task-068). Emitted by TeleportSystem when the player stepped on a working pad's centre and a trip begins:
## `from_centre` the source centre (world, on the floor), `candidates` the centres of every pad of the target channel,
## `chosen_index` the one the trip goes to, `duration` the whole trip in seconds. Movement and the menu are blocked
## until teleport_finished.
signal teleport_started(from_centre: Vector3, candidates: Array[Vector3], chosen_index: int, duration: float)
## Emitted by TeleportSystem when the body has been moved to the destination centre (the arrival wave plays).
signal teleport_arrived(centre: Vector3, candidate_count: int)
## Emitted by TeleportSystem when the trip is over (or was cut short by the run ending); movement is free again.
signal teleport_finished

## Dirt walls (task-070). The ONE way to remove a dirt cell: anyone (the player eating it, later a cannon ball) asks
## with the cell and a cause (DirtWalls.CAUSE_EATEN, ...); DirtWalls (the only writer of the dirt state) destroys it
## when it is still dirt.
signal dirt_destroy_requested(cell: Vector2i, cause: StringName)
## Emitted by DirtWalls when a dirt cell was destroyed and is floor now (collision, sight and light already updated in
## the map data). Presentation and the light / reveal follow it.
signal dirt_destroyed(map_id: StringName, cell: Vector2i, cause: StringName)
## Emitted by DirtWalls when every destroyed dirt cell of the map became dirt again (run start); `cells` = those cells.
signal dirt_restored(cells: Array[Vector2i])

## Interact (task-072). Emitted by Interactables when the interactable in reach of the player changes: `available`
## false when none is in reach; `centre` its footprint centre (world, on the floor). The hint glyph follows it.
signal interact_focus_changed(available: bool, centre: Vector3)
## Emitted by Interactables when an interact hold starts (true) or ends (false). While it is held the press belongs to
## the object: the player does not walk toward the cursor.
signal interact_hold_changed(holding: bool)

## Destructibles (task-073). Emitted by the owner of a destructible thing (DirtWalls, LargeObjects, TeleportSystem,
## later the enemies) every time one was destroyed: `kind` its Destructibles kind (dirt, a large object type, teleport,
## ...), `rect` its footprint in cells, `world_position` the footprint centre on the floor, `cause` who did it
## (DirtWalls.CAUSE_EATEN, CannonBalls.CAUSE_CANNON, ...). Remains and effects hook in here.
signal destructible_destroyed(kind: StringName, rect: Rect2i, world_position: Vector3, cause: StringName)
## Emitted by the owner when a destroyed thing is back (run start; dirt uses dirt_restored instead).
signal destructible_restored(kind: StringName, rect: Rect2i)
## Cannon (task-073). Emitted by CannonSystem for every ball fired: the cannon's index, the muzzle (world) and the
## ball's direction on the ground plane. The boom and the muzzle flash follow it.
signal cannon_fired(cannon_index: int, muzzle: Vector3, direction: Vector3)
## Emitted by CannonBalls when a ball bounced off something indestructible (world position of the bounce).
signal cannon_ball_bounced(world_position: Vector3)

## Enemies (task-075). Emitted by EnemySystem (the only writer of the enemy state) when every enemy of the map stands on
## its spawn again (map build, run start); `count` = enemies of the map. EnemyView rebuilds from it.
signal enemies_reset(count: int)
## Emitted by EnemySystem when an enemy was destroyed (a cannon ball, a black hole, ...), right after the generic
## destructible_destroyed(EnemySystem.KIND, ...): `kind` its EnemyDef.kind, `cell` the cell it was drawn in,
## `world_position` where it was (floor level), `cause` who did it. EnemyRemains answers with diamonds or a black hole.
signal enemy_destroyed(kind: StringName, cell: Vector2i, world_position: Vector3, cause: StringName)

## Enemy remains (task-076). Emitted by EnemyRemains (the only writer of diamonds and black holes) when diamonds burst
## out of `from_position` onto `cells` (the burst animation flies them there).
signal diamonds_spawned(from_position: Vector3, cells: Array[Vector2i])
## Emitted by EnemyRemains when the player walked over a diamond: `total` = diamonds collected ever (the save counter).
signal diamond_collected(cell: Vector2i, total: int)
## Emitted by EnemyRemains when a black hole formed in `cell` (a destroyed hunter).
signal black_hole_formed(cell: Vector2i, world_position: Vector3)
## Emitted by EnemyRemains when diamonds and black holes went back to the map file's picture (map build, run start).
signal remains_reset
