# Game Design: Godot Narrator

## One-line
An ASCII-art, morphing-visuals storyteller roguelike in which a single exotic character wakes in an unknown world, discovers how to move, and is told conflicting stories about what it is.

## Vision
The player begins as one ASCII-art character in an empty, silent world. There is no tutorial text and no fixed control scheme: the game registers whichever input the player uses first (keyboard, mouse, gamepad) and maps movement to it. The world reveals itself through play, as walls, items and hazards appear as the character explores, in the style of a treasure hunt.

A narrator offers the character a history and a sense of self. The narrator's accounts of what the character is and where it came from contradict each other, and the true origin is never revealed. The narrator speaks through morphing ASCII text and ambient sound, not voice (voice is a possible later addition).

The game is a roguelike. Each death ends a run, progress is saved, and the next run starts again. Between runs the player unlocks permanent functions, new starting points, items, skills and parts of the world, so that each run adds one more piece to the story. Over time the character gains access to other views and dimensions (see Open Questions), and the world expands according to the choices the player made.

Visual identity is central. The world is real 3D geometry shown in an isometric 2.5D view from the first frame. The surfaces carry ASCII glyphs as a material (lighting picks the glyph and its brightness), and morphs are built from many glyph objects that fly, rotate and reassemble, for atmosphere.

## Pillars
1. **Always in play (flow).** No pause screen. Menus and narration live inside the world. Flow over friction.
2. **Discovery through play.** The game teaches by letting the player find out: controls, world, rules and story.
3. **ASCII morphing as eye-candy.** The look is as close to pure text characters as possible. Surfaces use glyph-atlas materials, and morphs are shapes built from many glyph objects that fly, rotate and reassemble.
4. **Narrator-guided identity.** The narrator gives the character a history and a sense of self, and the player pieces it together across runs.
5. **No single truth.** The character's true origin is never answered, for the whole game. The narration contradicts itself across runs (hero or villain; alien; an AI that collected itself back together after a war; occult, demonic at times and angelic at others). There is never one answer. Some options can be ruled out through gameplay, but no single account is ever confirmed.

## Core Loop

### First run
1. Black screen with an abstract wave effect.
2. A random, exotic ASCII-art character appears in the middle of the screen. Its identity is chosen at random on this first run and kept across runs (see Character Identity).
3. The player provides any input. The game maps the first input used to movement (adaptive mapping).
4. The world reveals walls, items and hazards as the character explores.
5. The character dies to a hazard.
6. Progress is saved and the game starts a new run.

### Deaths and persistence
- The first death saves progress and restarts the game into a new run.
- Saved progress persists across launches.
- Saved progress in M1 covers: death count, revealed map memory, narration progress, and character identity (see Save and Persistence).

### Menu unlock after 3 deaths
- After the third death the in-world menu becomes available to the player.
- The menu is not a pause. It is built from the surroundings: glyph objects lift off the scene and rearrange into menu elements.
- Early on the menu is hard to read. As the player uses it, it gradually simplifies into a more user-friendly form.
- The menu offers a switch between the single-glyph and multi-glyph forms of the character (see Character Identity).
- Decided (task-018): it unlocks when the saved death count reaches `menu_unlock_deaths` (default 3, `resources/config/menu_config.tres`; persisted like the entity unlock). Tab / gamepad Start / right mouse button opens and closes it; W/S or arrows (D-pad, stick) move the selection, Enter / Space / gamepad A confirm, hover and left click work on items. It never pauses: hazards, erosion and narration keep running; only movement input is taken over and the player stands still. It only opens during a run and closes when the run ends.
- Look: glyphs of the floor and walls within about 3 cells lift off (flip, spin, eased flight with overshoot, Spike B style) into a framed, glowing list above the player; the floor around the player dims while they are away; on close they fly back. Items are data (`MenuItemDef` resources): "become many" / "become one" (the form switch, only offered when the entity is unlocked; it closes the menu so the morph is seen) and "return".
- Exact unlock mechanics are open (see Open Questions).

### Later runs
- The narrator and the player's choices expand the world across runs.
- Players can switch dimensions and views, use items, skills and special abilities, and unlock new capabilities.
- Each run may add one piece of the story.
- The narrator's tone shifts as runs accumulate (see Narrator).

## Core Mechanics

### Movement and adaptive input
- Movement is mapped to whichever input device the player first uses: WASD, arrow keys, mouse, gamepad, or others.
- Mapping is adaptive and decided on first use. Once registered, it is used for movement.
- All input is routed through Godot's InputMap (see the project conventions).

### Reveal and discovery
- The world is hidden at start and reveals walls, items and hazards as the character reaches them.
- Discovery is the main source of information. No tutorial overlays are planned.
- Reveal radius is 2.75 cells (smaller than the player light, so the opening is a plain disc of floor); revealed cells materialise glyph by glyph over about a second. Cells remembered from earlier runs show dim, cool, desaturated and sparse, without glow, and turn live again smoothly when re-seen.

### Hazards and death
- M1 hazards:
  - **Spikes:** static tiles that kill the character on touch.
  - **Corrupting glyphs:** areas that scramble and erode the character over time. The exact erosion rule lives in `.tres` resources.
- Void/pits and collapsing tiles are not in M1.
- Narrative choices can also deliberately end a run.
- There are no hostile creatures in v1.
- A death ends the run; progress is saved and the run restarts.

### Narrative choices
- Some player choices are narrative and can end a run on purpose.
- Narrative consequences are recorded and feed the story across runs.
- Specific choices are not designed yet (see Open Questions).

### Narration contradictions and rule-outs
- Narration contradicts itself across runs. Accounts include: hero or villain, alien origin, an AI reassembled after a war, and occult (demonic or angelic).
- No account is ever confirmed. The true origin is never revealed.
- Some accounts can be ruled out through gameplay. Draft design: see Origin Contradiction and Rule-Out System (task-016, awaiting user review).
- The design of this system is part of M2.

### Character Identity
- Identity is chosen at random on the first run and stays the same across runs.
- Identity changes over time as runs accumulate.
- After the third run, the character extends into a multi-character entity that is larger and made of multiple glyphs.
- Trigger (decided, task-017): the entity unlocks when the saved death count reaches `growth_unlock_deaths` (default 3, `resources/config/entity_growth_config.tres`). In M1 every run ends in a death, so this is "after the third run". The unlock is saved and survives restarts. At the start of the first run after it, the single identity glyph gathers glyphs from around it into a creature silhouette (about 25-37 glyphs, the identity glyph is its heart), then the grown entity is the active form by default. The silhouette is one of a few text-pattern formations picked by the identity, so an identity always grows the same body. Switching back is the M2 menu (task-018).
- A menu option lets the player switch between the original single-glyph form and the multi-glyph entity.
- The multi-glyph entity has abilities the single-glyph form lacks, for example moving small objects. These are not possible during the first three runs.
- Small-object pushing (decided, task-019): small objects are marked `o` in the map file. Only the grown form moves them: pressing against one for a moment slides it one cell (Sokoban style, along a world axis) if the cell behind it is plain floor (not a wall, void, another object, item, spawn, spikes or corruption). The single glyph is blocked by them like by walls. Objects return to their map cells at every run start. Pushing emits `SignalBus.object_moved` (the hook for the alien trial; no narration). Parameters: `resources/config/push_config.tres`.
- The growth into the multi-glyph entity is tied to the M2 menu unlock. It is shown as a glyph-object morph (see Morphing).

### Narrator
- Narration is shown as ASCII letters that fly in and assemble into a sentence on screen (see Morphing).
- Ambient sound effects accompany narration.
- Narration is triggered by events or by time.
- Tone shifts over runs: the narrator starts cryptic and sparse, and grows clearer and more personal as runs accumulate.
- No voice in v1.

### Save and persistence
- Progress is saved after each death.
- Saved progress in M1 includes:
  - Death count.
  - Revealed map memory: previously seen areas are remembered across runs. How remembered areas are displayed is open (see Open Questions).
  - Narration progress: heard beats do not repeat, and new beats unlock.
  - Character identity.
- Unlocked meta-progression is saved as well (see Open Questions for the list).

### Camera and dimension views
- The camera is isometric 2.5D from the first frame. There is no 2D start and no later unlock of a 2.5D view.
- Whether switching views is still a progression feature is open (see Open Questions).
- Full 3D gameplay is out of scope for v1.

### Morphing
- Morphing and animated ASCII transitions are the visual default.
- A morph is a shape built from many glyph objects (batched glyph quads) that fly, rotate and reassemble into a new shape. It is not one glyph blending into another.
- Examples: the hero grows into the multi-glyph entity; surroundings lift off and become menu items; narration letters fly in to form a sentence.
- Morphing is used for narration, menus, character growth and abilities.
- Animation timing and intensity: TBD (lives in .tres resources).

## Rendering Approach
- The world is real 3D geometry (walls, floor, objects), shown in an isometric 2.5D view from the first frame.
- Surfaces use glyph-atlas materials: ASCII is applied as a material on the 3D surfaces, and lighting picks the glyph and its brightness (reference: Illuminascii).
- Actors, effects, menus and narration are built from MultiMesh glyph objects (batched glyph quads) for morphing.
- Glow is cheap: additive halo sprites, not full-screen bloom.
- Target: integrated OpenGL 3.3 GPU (Intel HD 2500/4000 class), stable 30+ FPS, Compatibility renderer only.
- Superseded (decision-002): the full-screen ASCII post-process shader (task-023/024, "Midnight Neon") is replaced. It stays in the code until the rebuild.
- Gameplay code uses 3D nodes. Camera and view changes happen through a camera rig.

## Content

### Maps
- Maps are handcrafted and stored in files.
- No procedural generation.
- A world map editor is wanted but is not part of M1 (see Milestones).

### Player features (list, not yet designed)
- Adaptive key mapping (or other input mappings)
- Menu usage
- Character forms (single-glyph and multi-glyph entity)
- Capabilities
- Special abilities
- Items
- Skills
- Achievements

### Narrator content
- Event-triggered or time-triggered audio and audio-visual effects.
- Story beats: M1 has a few beats (not yet written). Each beat is heard once; new beats unlock with progress. The full beat list is TBD.
- Contradicting accounts: see Narration contradictions and rule-outs.

### Future meta-progression (recorded, not decided)
- Permanent functionalities
- New starting points
- Items
- Skills
- World parts
- Achievements

## Milestones

| Milestone | Name | Status |
|---|---|---|
| M1 | Awakening Run (vertical slice) | Current |
| M2 | Menu & Meta | Tentative |
| M3 | Dimensions & Abilities | Tentative |
| M4 | World Editor & Content | Tentative |

### M1 Awakening Run (vertical slice)
Black screen and abstract wave, then a random exotic ASCII character spawns in the middle. Its identity is chosen at random and kept. Movement is discovered through any input. The world reveals walls, items and hazards during exploration. Hazards are spikes and corrupting glyphs. The character dies to a hazard, progress is saved (death count, revealed map memory, narration progress, character identity), and the game restarts into a new run. One handmade map. No pause. Narration is limited to a few M1 beats.

M1 rendering is being rebuilt (decision-002, 2026-10-30). Two throwaway spikes come first: Spike A (glyph-material isometric world) and Spike B (glyph-object morph moments: hero grows, surroundings become menu, narration assembles). The rebuild follows the user's pick from the spikes.

### M2 Menu & Meta (tentative)
- In-world morphing menu unlocks after 3 deaths.
- Entity growth: after the third run, the character extends into a multi-glyph entity.
- Menu option to switch between the single-glyph form and the multi-glyph entity.
- Small-object pushing ability on the multi-glyph entity.
- Narration contradiction and rule-out system design.
- Initial meta-progression. Details undecided.

### M3 Dimensions & Abilities (tentative)
Abilities and item/skill foundations. View and dimension unlocks: undecided (the 2.5D unlock is dropped, see decision-002). Details undecided.

### M4 World Editor & Content (tentative)
World map editor. Additional handcrafted maps and content.

## Out of Scope (v1)
- Full 3D gameplay. The world is 3D internally and is presented in an isometric 2.5D view.
- Hostile creatures and enemy AI.
- Voice acting for narration.
- Procedural world generation.
- World map editor (planned for M4).
- Other view modes beyond the isometric 2.5D view: undecided (see Open Questions).
- Pause menu. (Excluded by design.)

## Origin Contradiction and Rule-Out System

**Status: approved by the user on 2026-11-02** (task-016). All numbers are defaults that live in `.tres` resources. Implementation: task-039 to task-045.

### 1. Hypotheses and how beats reference them
The existing origin tags split into two axes. A single flat list would not work: "hero" and "alien" do not exclude each other, so two survivors like {hero, alien} would still read as one answer ("a heroic alien").
- **Nature axis** (what it is): `alien`, `ai`, `demonic`, `angelic`. Only this axis can be ruled out.
- **Deed axis** (what it did): `hero`, `villain`. This axis is testimony and can never be ruled out. Both deeds always stay open, and the narrator keeps arguing both sides.
- `none` is not a hypothesis. It means the beat is neutral.

Each beat holds a **stance** toward each hypothesis: `supports`, `contradicts`, or neutral (not listed). The former origin tags (now `supports`) hold the hypotheses a beat speaks for. A `contradicts` entry is added where the text denies an account (see 5). The player never sees the stances. They are used for narrator selection, ledger feedback and content checks.

### 2. How gameplay rules a nature out: claims and trials
A rule-out is never stated by the narrator. The player earns it by **disproving something the narrator claimed**.
1. **Claim.** One claim beat per nature makes a testable statement of the form "if you were X, you could never Y". It reads as a taunt, not as a rule. Example (demonic): "If the static reads your name, it keeps you." Hearing the claim **arms** that nature's trial. Without the claim, the trial cannot fire, so every rule-out has been set up in the fiction first (pillar: discovery through play).
2. **Trial.** A trial is a systemic condition, checked from signals the game already emits:

| Nature | Claim (gist) | Trial (falsifier) | Built on |
|---|---|---|---|
| `demonic` | Its name in the static would keep it. | Reach `erosion_high`, leave the corruption, and stay alive for `demonic_survive_s` (15 s). | erosion, hazards |
| `ai` | What collected itself would never come apart by choice. | Choose "become one" in the menu, then survive `ai_single_s` (60 s) in single form in the same run. | menu, entity form |
| `angelic` | Bright things cannot rest in the dark. | Stand idle for `angelic_dark_s` (20 s) on a cell at least `dark_distance` (6) cells from any light-source cell (item, spikes, corruption). | idle, map data |
| `alien` | What fell from the stars cannot hold what was made here. | Move a small object with the grown entity (M2 pushing). The trial stays dormant until pushing exists. | entity ability |

3. **Strike.** When a trial passes, the nature is **struck**. The cap is `max_strikes_per_run` (1) per run. The strike is saved at once, not only at death.

**Player-readable feedback** (the answer is never told, only "not that"):
- **Narrator reaction.** A `claim_broken` beat plays right away. It sounds unsettled, not triumphant. Example: "...Then not the stars." Its mood comes from the struck nature.
- **Doubt rendering.** Later beats whose `supports` contain only struck natures still play, but their letters do not fully settle: some glyphs keep scrambling (`doubt_scramble`). The narrator keeps saying the old line, and the line no longer holds together.
- **Ledger in the menu.** A new `MenuItemDef` named "remember" opens a row of six sigils, one glyph per hypothesis, defined in data. They are built from the surroundings like the rest of the menu: struck natures do not lift with the others and stay dim on the floor, and a recanted nature lifts with a crack glyph beside it. The two deed sigils always lift but never settle; they keep swapping places. Label legibility follows the menu's simplification over use. Opening the ledger is still not a pause.

### 3. The guarantee
**Invariant: at least `min_alive_nature` = 2 nature hypotheses are always alive, and deed hypotheses can never be struck. Every account therefore has at least 2 x 2 = 4 open combinations, and no sequence of runs leaves exactly one answer.**

Argument:
- `OriginLedger` is the only writer of the struck list, and it has only two operations.
- `strike(h)`:
  - It is a no-op if `h` is already struck or is a deed.
  - If striking would drop the alive count below the floor, it first **recants** the oldest struck nature (FIFO) and then strikes `h`. That recant always exists: at the floor with 4 natures, 2 are struck, and `h` is not one of them.
  - The alive count is never below the floor afterwards.
- `recant(h)` only raises the alive count.
- On load, a save with fewer than 2 alive natures is repaired by recanting the newest strikes. A config value below 2 is clamped to 2 with a logged error.
- No other code path changes the list, so the invariant holds by induction over every operation, in any number of runs.
- Content rule: no beat may be `CONFIRM`-like. Every beat that supports a single nature must have a later or parallel beat that supports a different one (checked by the lint in task B).

**Narrator behaviour as options shrink:**
- **4 alive:** normal play.
- **3 alive:** beats that support a struck nature render with doubt.
- **2 alive (floor):**
  - The next successful trial causes a **recant**. The narrator reclaims what it lost, for example: "No. I was too sure. The stars come back." The recant beat restates that nature's claim and re-arms its trial with its threshold multiplied by `retry_scale` (1.5) per previous strike, so ping-pong gets slower each time.
  - In ladder ties, beats that support both survivors at once are preferred. This turns the narrator's contradiction onto the last two.
- The truth slips; it never converges.

### 4. Data model sketch
- **`OriginHypothesis`** Resource (`resources/origin/*.tres`):
  - `id` (StringName), `axis` (NATURE/DEED), `sigil` (String glyph), `label` (String)
  - `claim_beat_id`, `broken_beat_id`, `recant_beat_id`
  - `trial: OriginTrial` (null for deeds)
- **`OriginTrial`** Resource:
  - `kind` enum: EROSION_ESCAPE, SINGLE_FORM_SURVIVE, DARK_IDLE, OBJECT_MOVED
  - `seconds` (float), `distance` (int), `requires_entity_unlocked` (bool)
- **`OriginConfig`** (`resources/config/origin_config.tres`):
  - `hypotheses: Array[OriginHypothesis]`
  - `min_alive_nature` (2, clamped to at least 2), `max_strikes_per_run` (1), `retry_scale` (1.5), `doubt_scramble` (0.3), `tie_prefer_dual_support` (bool)
- **`NarrationBeat`** additions:
  - `supports`, `contradicts` (PackedStringArray; they replaced the old origin tags)
  - `role` enum: STORY, CLAIM, BROKEN, RECANT
  - `event_param` (StringName; the hypothesis id for `claim_broken` and `claim_recanted`)
- **`PersistentProgress`** additions:
  - `struck_natures` (PackedStringArray, ordered oldest first)
  - `armed_trials` (PackedStringArray)
  - `strike_counts` (Dictionary id -> int, used for the retry scaling and the ledger crack)
  - `last_strike_run` (int, enforces the per-run cap)
  - Missing fields default to empty.
- **Nodes:**
  - `OriginLedger` (logic, after `SaveService`): the sole mutator; it enforces the invariant.
  - `OriginTrialMonitor` (logic): listens to `erosion_changed`, `run_ended`, `entity_form_changed`, `idle`, the player cell and the future `object_moved`, and runs timers for armed trials only.
- **SignalBus:**
  - `origin_trial_passed(id)` (monitor -> ledger)
  - `origin_struck(id)`, `origin_recanted(id)`, `origin_ledger_changed(alive, struck)` (the narrator, the menu and the doubt rendering listen)
  - `origin_claim_heard(id)` (narrator -> ledger, arms the trial)
- **Narrator eligibility:**
  - A CLAIM beat is eligible only while its nature is alive and unarmed.
  - BROKEN and RECANT beats fire on their events with a matching `event_param`.
  - Doubt is a display flag passed to the overlay.

### 5. Content implications for the 26 M1 beats
- **Retag only (text unchanged):**
  - `supports` = the current tags, with `hero`/`villain` now on the deed axis.
  - New `contradicts` entries:
    - `start_came_back` contradicts `demonic` (it returned by choice, not bound).
    - `corrupt_after_war` contradicts `demonic` (machine, not name).
    - `erosion_true_name` contradicts `ai`.
    - `death_spikes_willing` contradicts `villain`.
    - `idle_burned` contradicts `hero`.
  - `start_hero_lied` and `wall_keep_them_out` support both deeds.
- **Imbalance:** `ai` is supported by 6 beats (mostly corruption), `demonic` by 5, `alien` and `angelic` by 4 each. No beat contradicts `alien` or `angelic`.
- **Gaps:**
  - At least one beat contradicting `alien` and one contradicting `angelic`.
  - 4 CLAIM beats, 4 BROKEN beats and 4 RECANT beats (12 short lines). The alien set ships dormant.
  - Claims gate at `min_deaths` 3 or more, so they arrive with the menu and the ledger.
  - Beats for runs 7 and later that support both survivors, to fill the intended start silence.
- No new line may name a control or say "ruled out". The fiction is always "I was wrong" or "I was too sure".

### Proposed backlog tasks
**A. Origin ledger and invariant**
- `OriginHypothesis`, `OriginTrial` and `OriginConfig` exist and are built by a `tools/` builder. The 4 nature and 2 deed `.tres` files load.
- `OriginLedger` is the only writer of `struck_natures`. A headless test applies 1000 random strike sequences and asserts that at least 2 natures are always alive and that the deeds are never struck.
- Loading a save with 3 struck natures repairs it to 2 struck (the newest strike is recanted) and logs a warning.

**B. Beat stance retag and content lint**
- `NarrationBeat` has `supports`, `contradicts` and `role`. All 26 beats are migrated as in 5, and the old origin tags field is removed.
- A lint run by the builder fails if any nature lacks a supporting or a contradicting beat, or if a beat lists a hypothesis in both `supports` and `contradicts`.

**C. Trial monitor (demonic, ai, angelic)**
- Each trial fires `origin_trial_passed` only while it is armed and its nature is alive. Thresholds come from config.
- At most one strike per run (`last_strike_run`), and the strike is saved immediately.
- A headless test drives the signals and checks one pass and one non-pass case per trial.

**D. Narrator integration**
- Hearing a CLAIM beat arms its trial. BROKEN and RECANT beats play on `origin_struck` and `origin_recanted` with the matching `event_param`.
- Beats whose `supports` are all struck play with the doubt flag. The overlay keeps `doubt_scramble` of the glyphs unsettled.
- At the floor, tie-breaking prefers beats that support both survivors.

**E. Ledger menu item "remember"**
- A new `MenuItemDef` opens the sigil row built from surrounding glyphs, with no pause. Struck sigils stay on the floor, recanted ones show a crack, and the deed sigils never settle.
- It is offered only after a claim has been heard. It stays within the menu's single MultiMesh draw call. Visual check by the user.

**F. Claim, broken and recant lines (user-authored or user-approved)**
- 12 lines plus 2 contradicting lines for `alien` and `angelic`, added to `docs/narration_m1.md` (or an M2 narration doc). They follow the tone curve and the no-tutorial rule.
- The task B lint passes with the new beats.

**G. Alien trial (blocked by entity pushing)**
- OBJECT_MOVED fires when the grown entity moves a small object while the alien trial is armed. The alien CLAIM beat stops being dormant.

**Later (not M2):** run-ending narrative choices add testimony to the deed axis. The narrator answers with a beat for the opposite deed (contrarian), and no deed is ever struck.

## Open Questions and Risks

### Risks
1. **Narration and menus under the ASCII shader.** A full-screen post-process shader will scramble text and in-world menus if they are rendered in the 3D scene. Options: (a) render narration and menus as an overlay layer that bypasses the shader, or (b) design the text so it survives the shader. **Resolved** by Backlog decision-001: narration and menus render on an overlay CanvasLayer (layer >= 10) above the shader (option a). *Note (decision-002): that shader is superseded; whether this overlay is kept in the rebuild is open.*
2. **Character identity under the shader.** How the "exotic ASCII art" identity of the player character survives a post-process shader depends on shader cell size relative to character size. The larger multi-glyph entity (M2) makes this harder to keep readable. **Resolved** by decision-001: the identity glyph is drawn on the overlay at `camera.unproject_position` of the player's 3D position, so it does not depend on the shader cell size. *Note (decision-002): that shader is superseded; the rebuild's approach is open.*

### Open Questions
- How closely overlay glyph size should track the shader cell size (follow-up from decision-001, settle with the multi-glyph entity in M2). Likely moot while the post-process is superseded by decision-002; confirm in the rebuild.
- Glyph-atlas materials: glyph ramp per surface type, atlas contents, and how lighting maps to glyph choice and brightness (reference: Illuminascii). Not designed.
- Morph system: glyph counts per morph, batch sizes, timing and easing for glyph-object morphs. TBD.
- Halo sprites: size, intensity and which elements get a halo. TBD.
- Performance budget: per-pass millisecond budgets are not set. The target is stable 30+ FPS on Intel HD 2500/4000 class GPUs. The old 60 FPS GTX 1060 budget in the superseded visual spec no longer applies.
- Spike outcome: which spike result (Spike A glyph-material isometric world, Spike B glyph-object morph moments) the user picks. The rebuild waits for this choice.
- View switching: whether it remains a progression feature now that isometric 2.5D is the starting view, and whether any other view modes exist.
- Milestone M3 view unlocks: what "Dimensions & Abilities" covers now that the 2.5D unlock is dropped.
- Whether the old flicker and morph limits in the superseded visual spec (section 6) carry over to the new direction. Not decided.
- Exact unlock mechanics and costs for the post-3-death menu (M2).
- Whether the third run and the third death are the same trigger for the menu and for the multi-glyph growth.
- How identity changes over time beyond the third-run growth (stages, pacing, what changes).
- Pool and rules for random identity generation on the first run.
- Full ability list for the multi-glyph entity, and how small-object pushing works.
- Rule-out mechanics and how contradicting beats are authored: draft answer in Origin Contradiction and Rule-Out System (task-016). Open until the user reviews it.
- Narrator tone: the run counts at which the cryptic-to-clear shift happens, and how it is paced.
- How revealed map memory is displayed (for example, faintly) and how it differs from currently visible areas.
- Which meta-progression systems exist, and what each one costs and unlocks (permanent functions, starting points, items, skills, world parts, achievements).
- What "run capability" means in mechanical terms, and how it is built during a run.
- Which narrative choices end a run, and which are reversible.
- Story content and narration beats beyond the M1 set.
- Specific dimension and view mechanics for 2.5D and 3D-style views.
- Adaptive input mapping rules when several devices are used at once.

### Tuning Values
All numbers are TBD and live in `.tres` resources or exported variables. This includes timings, sizes, speeds, counts, and visual parameters. This also includes the corrupting glyph erosion rule.
