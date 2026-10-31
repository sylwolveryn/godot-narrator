# Architecture (M1)

Decided 2026-10-30 for M1; update as tasks land.

Engine: Godot 4.7.2, GDScript, renderer `gl_compatibility` (keep it). Static typing everywhere.

## Folder Layout

All folders and files use snake_case.

- `scenes/`: `.tscn` files, built ONLY by tool scripts in `tools/` (never hand-edit `.tscn`/`.tres` text).
- `scripts/core/`: `signal_bus.gd`, `run_manager.gd`, `save_service.gd`, config resource classes.
- `scripts/world/`: map loader, map data, reveal, hazards.
- `scripts/player/`: player body, identity, input discovery.
- `scripts/rendering/`: camera rig, glyph world view and config, glyph overlay.
- `resources/glyphs/`: the glyph atlas PNG and the glyph-surface material (`tools/build_glyph_atlas.gd`, `tools/build_glyph_material.gd`).
- `scripts/narrator/`: narrator system, beat resource.
- `scripts/ui/`: intro sequence, overlay presentation.
- `resources/config/`: `.tres` config instances (built by `tools/build_resources.gd`).
- `resources/narration/`: narration beat `.tres` files.
- `data/maps/`: handcrafted ASCII map text files.
- `shaders/`: `.gdshader` files.
- `tools/`: `extends SceneTree` headless builders.
  - Run: `godot --headless --path . -s tools/<name>.gd`
  - Each builder is idempotent and is the source of truth for the scene/resources it writes.
  - When overwriting an existing `.tscn`, keep its UID (see `tools/build_main_scene.gd`: `ResourceLoader.get_resource_uid` + `ResourceSaver.set_uid`).

## Layers and Rules

- Layering: UI (presentation) → Logic (controllers/state nodes) → Data (Resources) → Infrastructure (`SignalBus` autoload).
- ONE autoload: `SignalBus` (`res://scripts/core/signal_bus.gd`). Signals only, no state.
- Signals travel UP. Presentation never writes data. Children emit; parents/managers call down.
- No game state in autoloads.
  - Run state lives in a `RunManager` node (child of Main).
  - Persistent state lives in a `PersistentProgress` Resource owned by a `SaveService` node.
- No magic numbers in gameplay code. Every tunable is an `@export` on a config Resource class (`class_name XConfig extends Resource`) with defaults. Instances are saved as `.tres` in `resources/config/` and assigned via `@export` on the node that uses them.
- All input goes through InputMap actions in `project.godot` `[input]`. `project.godot` may be edited as text or via ProjectSettings in a tool script. No raw keycodes in code.
- No `load()` in `_process`.
- No `get_tree().root.get_node()` deep in logic.

## World Model

- The world is real 3D. The gameplay plane is XZ (y up).
- One map cell = 1 world unit. The cell size lives in `WorldConfig`.
- Camera (task-031, decision-002): isometric orthographic from the first frame, no 2D start.
  - `CameraRig` (Node3D + Camera3D) is driven only by a `CameraViewConfig` (`resources/config/camera_isometric.tres`: ortho size 12.6, pitch -35.264, yaw 45, look height, near/far, follow smoothing). The camera sits at +x,+z looking toward -x,-z; the rig follows the player on the XZ plane. `camera_tilted.tres` is a perspective profile used by `tools/test_camera_rig.gd` to prove views can be swapped.
  - Because the camera always sits at +x,+z, `WorldMeshBuilder` only emits tops, +x faces and +z faces. Changing the yaw means changing that too.
- Walls: StaticBody3D collision (one per horizontal run); the visible walls, floor, items, spikes and corruption are one merged mesh (see Rendering).
- Items, hazards: `MapCell` Area3D (collision/trigger only, no mesh of their own).

## Rendering

### Direction (decision-002)
- Surfaces (walls, floor, objects) are glyph-atlas materials on isometric 3D geometry; lighting picks the glyph and its brightness. There is no full-screen post-process pass.
- Actors and effects are batched billboards: the player glyph and its fragments (task-033, `PlayerGlyphView`), glow as cheap additive halo sprites (`GlyphHaloField`), no full-screen bloom. Narration, menu and the intro stay on the overlay (task-034).
- Potato budget: stable 30+ FPS on integrated OpenGL 3.3 GPUs (Intel HD 2500/4000 class), Compatibility renderer only. Per-pass millisecond budgets are not set yet.
- History: the earlier full-screen ASCII post-process pipeline was superseded by decision-002 and removed in task-035. Spikes under `scenes/spikes/` are kept as reference only.

### Glyph-surface world (task-031)
- `MapLoader` builds the WHOLE map as ONE `ArrayMesh` (`WorldMeshBuilder`, one surface, one draw call, ~5k triangles for M1) with ONE `ShaderMaterial` (`resources/glyphs/glyph_surface_material.tres`, shader `shaders/glyph_surface.gdshader`). Per vertex: `COLOR.r` = `GlyphSurfaceType` id / 8 (wall, floor, spikes, corruption, item), `UV` = the map cell, `NORMAL` = face normal. Every non-void cell has a floor quad; walls are boxes (top + +x/+z faces); items are pillars, spikes pyramids, corruption columns.
- The shader draws glyphs ON the faces: a glyph grid per face from world space (axes derived from `INV_VIEW_MATRIX`), light evaluated once per glyph cell from <= 8 analytic point lights (no shadows, no screen texture), brightness picks the glyph column from the type's atlas row (`resources/glyphs/glyph_atlas.png`, layout `GlyphAtlasSpec`, baked by `tools/build_glyph_atlas.gd`), palette per type from `GlyphWorldConfig`.
- `GlyphWorldView` (node in Main) feeds the material: static look from `GlyphWorldConfig` (`resources/config/glyph_world_config.tres`), light slot 0 = player light, slots 1..7 = the nearest static lights (`GlyphLightSource`: items, spike and corruption patches) whose cells were seen in this run, and the cut-away uniform.
- Wall cut-away: fragments of non-floor surfaces closer to the camera than the player and within `cutaway_radius` of the view ray through the player are discarded with a dithered edge, so walls never hide the player.
- Reveal and memory (task-032): `MapReveal` owns the `reveal_mask` global texture (one texel per cell, r brightness, g seen fraction, b glint, a floor flag) and only re-uploads it when a cell changed or a fade runs (`RevealConfig`: radius 2.75 cells, 0.9 s fade, stagger per cell, smoothstep growth). The shader reads it per cell (`UV`): r = 0 draws nothing; while r < 1 the glyphs of a cell materialise one by one (`reveal_spread`) and its density ramps up. g = 0 draws the memory look: desaturated, cool tint, dimmer, sparser (`memory_density`, `memory_dropout`, minimum density `memory_floor`, reduced glow), no light tint; when the cell is seen again g rises over `memory_to_seen_duration` and everything returns to the live look. Static lights (and halos, `halo_memory` = 0) only shine for cells seen in the current run; `MapReveal.cells_seen` tells `GlyphWorldView` to re-pick its lights. All values are in `RevealConfig` / `GlyphWorldConfig` (Memory, Reveal groups).
- Look pass (task-036): wall faces are carved stone in the shader (masonry blocks on a world grid, seams, static per-block variation, rims on free edges driven by vertex `COLOR.g` edge bits, darker wall feet), light falloff is sharper so glyphs get dense near lights, ambient fades with distance from the player light plus a faint fog towards the screen top. All values are in `GlyphWorldConfig`.
- Light occlusion (task-036): no shadow maps. `GlyphLightOcclusion` casts grid rays on the map (3 per cell, soft edges); `GlyphVisibilityMap` stores the result in two small RGBA8 textures (`light_vis_a/b`, one channel per light slot; floor region sampled bilinear, wall region nearest) that the shader reads per glyph cell (1-2 extra fetches). The player light is recomputed when the player changes cell (about 1.5 ms on a dev PC, blended over `occlusion_blend_time`); static lights are baked once at map build. Wall side faces sample the open cell in front of the face, so light does not leak to the far side of a wall.
- Static lights fade in and out (`static_light_fade_in/out`); the cut-away edge dims glyphs and drops whole glyph cells instead of per-pixel dither.
- No full-screen pass, no `WorldEnvironment` glow. The camera's `Environment` only sets the background colour.

### Tunables and render settings
- Tunables are Resources: `GlyphWorldConfig`, `RevealConfig`, `GlyphFxConfig`, `CameraViewConfig`, `DisplayConfig`. Pixel sizes scale with `DisplayConfig` (cell 10x14 at 1080p).
- Global shader parameter: `reveal_mask` (registered in `project.godot` by `tools/build_project_settings.gd`, set by `MapReveal`).
- Render settings: no MSAA/FXAA/debanding, no 3D glow, default linear tonemap.

### Player, halos and overlay (task-033)
- `PlayerGlyphView` (Node3D in Main): the identity glyph stands IN the world. One MultiMesh of camera-facing quads (`shaders/glyph_actor.gdshader`, ONE draw call): instance 0 is the player glyph plus its warm halo (premultiplied alpha: glyph and dark backing blend, the halo adds), the other instances are fragments. The glyph pictures come from a runtime atlas: a `SubViewport` rasterises the identity glyph and the substitute glyphs (`GlyphFxConfig.scramble_glyphs`) with `PlayerConfig.font_names` once, and again only when the identity changes (UPDATE_ONCE). Quads are lifted towards the camera and depth-tested, so walls in front hide the glyph unless the cut-away removes them.
- Entity growth (task-017): `EntityProgression` (data layer, right after `SaveService`) unlocks the multi-glyph entity when `PersistentProgress.death_count` reaches `EntityGrowthConfig.growth_unlock_deaths`, plays the grow moment once at the start of the first run after the unlock and owns the active form (`EntityForm.SINGLE` / `GROWN`; `set_form()` is the API for the menu, task-018). It writes `entity_unlocked`, `entity_form`, `entity_grow_played` through `SaveService` and speaks through `SignalBus.entity_unlocked`, `entity_grown` (narrator hook, no beat text yet) and `entity_form_changed(form, animate)`. `PlayerGlyphView` listens and drives `EntityGlyphView`: ONE extra MultiMesh (`shaders/glyph_entity.gdshader`, one more draw call) for the body glyphs around the heart (the identity glyph, still instance 0). The silhouette is an `EntityFormation` text pattern resolved per identity into an `EntityLayout`; the instance buffer is written once per identity and everything that moves (Spike B style grow: stagger, eased flight with overshoot, spin, scale pop, mid-flight glyph flip; bob; walking lag; fold; erosion; death burst) is computed in the vertex shader from uniforms. The body ignores the depth test, so walls never hide it. Resources: `tools/build_entity_growth.gd`.
- Erosion (`erosion_changed` signal): the glyph blends continuously into a substitute glyph (retargeted at most every `erosion_retarget_min`, always as a crossfade), warps in slow waves, grows a violet ghost, takes the hazard tint and fades; above `erosion_shed_threshold` it sheds a fragment every `erosion_shed_interval`. Death (`run_ended`): a short fully-eroded flash, then `death_fragments` fragments fly outward over `death_duration` and fade. Everything is driven by `TIME` and CPU timers, no per-frame random in shaders; fragments live in a preallocated pool, no per-frame allocations.
- `GlyphHaloField` (Node3D): one MultiMesh, one quad per item, spike and corruption cell (`shaders/glyph_halo.gdshader`, additive). The vertex shader reads the reveal mask: hidden cells collapse the quad, remembered cells keep `GlyphWorldConfig.halo_memory` (0 = none). Slow breathing per kind (corruption slides between its two hues); depth-tested, so walls in front hide a halo. No per-frame CPU work. Shared glow shape in `shaders/glyph_halo.gdshaderinc`.
- A `CanvasLayer` overlay is still used for narration text and the intro (task-034); the old player overlay glyph (`GlyphOverlay`) was removed.
- Draw calls of the whole frame: about 4 (world mesh, halos, actors, narration/intro canvas).

## Map Format (`data/maps/*.txt`)

- ASCII grid, one char per cell.
- Legend lives in the `MapLegend` resource (default):

| Char | Meaning |
|------|---------|
| `#` | wall |
| `.` | floor |
| ` ` (space) | void (nothing, out of bounds) |
| `@` | spawn |
| `*` | item |
| `^` | spikes |
| `%` | corrupting glyph area |

- Unknown chars log a warning and become floor.
- Missing `@` logs an error and spawns at the first floor cell.
- The loader never crashes on bad input.

## Run Lifecycle

- `RunManager` states: INTRO → PLAYING → DYING → (restart) INTRO-lite/PLAYING.
- Emits via SignalBus:
  - `run_started(run_index)`
  - `run_ended(cause)`
- Death never pauses. Restart happens automatically after a configurable delay.
- Intro (black screen + abstract wave) plays on game launch. Later runs may use a shorter re-entry (config).

## Persistence (M1)

- `PersistentProgress` Resource saved to `user://progress.tres` (ResourceSaver at runtime is fine; `user://` is not a project file).
- Fields:
  - `death_count`
  - `run_count`
  - `identity` (glyph string + seed)
  - `revealed_cells` (PackedVector2Array or Dictionary per map id)
  - `heard_beats` (PackedStringArray)
- Missing or corrupt file: fresh default + logged warning.

## Narrator

- `NarrationBeat` Resource fields:
  - `id`
  - `text`
  - `trigger` (enum EVENT/TIME)
  - event name or delay
  - `min_run`, `max_run`
  - `sfx` (AudioStream, may be null)
  - `once` (bool)
- `Narrator` node listens to SignalBus events and picks eligible beats.
- Presentation goes through the overlay with morphing text (glyph scramble → resolve).
- Heard beats persist.

## Validation Per Task

1. `godot --headless --check-only --script <file>` on each changed `.gd` file.
2. `godot --headless --path . --quit-after 60` must produce zero ERROR lines.
3. Visual check cannot be done headless. Note it as "visual not verified" in task notes.
