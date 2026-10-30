# Game Design: Godot Narrator

## One-line
An ASCII-art, morphing-visuals storyteller roguelike in which a single exotic character wakes in an unknown world, discovers how to move, and is told conflicting stories about what it is.

## Vision
The player begins as one ASCII-art character in an empty, silent world. There is no tutorial text and no fixed control scheme: the game registers whichever input the player uses first (keyboard, mouse, gamepad) and maps movement to it. The world reveals itself through play, as walls, items and hazards appear as the character explores, in the style of a treasure hunt.

A narrator offers the character a history and a sense of self. The narrator's accounts of what the character is and where it came from contradict each other, and the true origin is never revealed. The narrator speaks through morphing ASCII text and ambient sound, not voice (voice is a possible later addition).

The game is a roguelike. Each death ends a run, progress is saved, and the next run starts again. Between runs the player unlocks permanent functions, new starting points, items, skills and parts of the world, so that each run adds one more piece to the story. Over time the character gains access to other views and dimensions (2D, 2.5D, and later 3D-style views), and the world expands according to the choices the player made.

Visual identity is central. Everything is built from 3D geometry but presented as ASCII glyphs, and the ASCII presentation morphs and animates for atmosphere.

## Pillars
1. **Always in play (flow).** No pause screen. Menus and narration live inside the world. Flow over friction.
2. **Discovery through play.** The game teaches by letting the player find out: controls, world, rules and story.
3. **ASCII morphing as eye-candy.** The look is as close to pure text characters as possible, with morphing and animated transitions.
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
- The menu is not a pause. It is built from ASCII art that morphs the surroundings into menu elements.
- Early on the menu is hard to read. As the player uses it, it gradually simplifies into a more user-friendly form.
- The menu offers a switch between the single-glyph and multi-glyph forms of the character (see Character Identity).
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
- Some accounts can be ruled out through gameplay. How rule-outs work is undecided (see Open Questions).
- The design of this system is part of M2.

### Character Identity
- Identity is chosen at random on the first run and stays the same across runs.
- Identity changes over time as runs accumulate.
- After the third run, the character extends into a multi-character entity that is larger and made of multiple glyphs.
- A menu option lets the player switch between the original single-glyph form and the multi-glyph entity.
- The multi-glyph entity has abilities the single-glyph form lacks, for example moving small objects. These are not possible during the first three runs.
- The growth into the multi-glyph entity is tied to the M2 menu unlock.

### Narrator
- Narration is shown as morphing ASCII text that assembles on screen.
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
- The camera starts locked to a 2D top-down or side view.
- A tilted 2.5D view is unlocked later.
- Switching views is a progression feature, not a setting.
- Full 3D gameplay is out of scope for v1.

### Morphing
- Morphing and animated ASCII transitions are the visual default.
- Morphing is used for narration, menus and abilities.
- Animation timing and intensity: TBD (lives in .tres resources).

## Rendering Approach
- The world is a real 3D scene built from low-poly or simple geometry.
- A full-screen ASCII post-process shader converts the rendered image into ASCII glyphs.
- The camera starts in a locked 2D top-down or side view. The 2.5D tilted view is unlocked later.
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

### M2 Menu & Meta (tentative)
- In-world morphing menu unlocks after 3 deaths.
- Entity growth: after the third run, the character extends into a multi-glyph entity.
- Menu option to switch between the single-glyph form and the multi-glyph entity.
- Small-object pushing ability on the multi-glyph entity.
- Narration contradiction and rule-out system design.
- Initial meta-progression. Details undecided.

### M3 Dimensions & Abilities (tentative)
Tilted 2.5D camera view unlock. Abilities and item/skill foundations. Details undecided.

### M4 World Editor & Content (tentative)
World map editor. Additional handcrafted maps and content.

## Out of Scope (v1)
- Full 3D gameplay. The world is 3D internally but is presented and played in 2D or 2.5D.
- Hostile creatures and enemy AI.
- Voice acting for narration.
- Procedural world generation.
- World map editor (planned for M4).
- Tilted 2.5D view (planned for M3).
- Pause menu. (Excluded by design.)

## Open Questions and Risks

### Risks
1. **Narration and menus under the ASCII shader.** A full-screen post-process shader will scramble text and in-world menus if they are rendered in the 3D scene. Options: (a) render narration and menus as an overlay layer that bypasses the shader, or (b) design the text so it survives the shader. **Resolved** by Backlog decision-001: narration and menus render on an overlay CanvasLayer (layer >= 10) above the shader (option a).
2. **Character identity under the shader.** How the "exotic ASCII art" identity of the player character survives a post-process shader depends on shader cell size relative to character size. The larger multi-glyph entity (M2) makes this harder to keep readable. **Resolved** by decision-001: the identity glyph is drawn on the overlay at `camera.unproject_position` of the player's 3D position, so it does not depend on the shader cell size.

### Open Questions
- How closely overlay glyph size should track the shader cell size (follow-up from decision-001, settle with the multi-glyph entity in M2).
- Exact unlock mechanics and costs for the post-3-death menu (M2).
- Whether the third run and the third death are the same trigger for the menu and for the multi-glyph growth.
- How identity changes over time beyond the third-run growth (stages, pacing, what changes).
- Pool and rules for random identity generation on the first run.
- Full ability list for the multi-glyph entity, and how small-object pushing works.
- Rule-out mechanics: which gameplay actions rule out which accounts, whether rule-outs are permanent or reversible, and whether and how the player sees them.
- How contradicting narration beats are authored and sequenced across runs.
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
