# Architecture (M1)

Decided 2026-10-30 for M1; update as tasks land.

Engine: Godot 4.7.2, GDScript, renderer `gl_compatibility` (keep it). Static typing everywhere.

## Folder Layout

All folders and files use snake_case.

- `scenes/`: `.tscn` files, built ONLY by tool scripts in `tools/` (never hand-edit `.tscn`/`.tres` text).
- `scripts/core/`: `signal_bus.gd`, `run_manager.gd`, `save_service.gd`, config resource classes.
- `scripts/world/`: map loader, map data, reveal, hazards.
- `scripts/player/`: player body, identity, input discovery.
- `scripts/rendering/`: camera rig, ascii post-process controller, glyph overlay.
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
- Camera:
  - `CameraRig` (Node3D) holds a Camera3D, orthographic, looking straight down for the "2D" view.
  - The rig exposes a view profile (`CameraViewConfig` resource: projection, size, pitch, follow smoothing).
  - A tilted 2.5D profile exists in config but is not selectable by the player in M1.
- Walls: simple box meshes + StaticBody3D.
- Floor: plane.
- Items: small meshes.
- Hazards: Area3D.

## Rendering

### ASCII Post-Process (task-023/024, spec: `docs/visual_direction.md`)
- The 3D world renders **data, not colour**. `MapLoader` gives every cell type a `ShaderMaterial` on `shaders/world_encode.gdshader` (unshaded). Each pixel: R = material id (`MaterialIds`), G = luminance (player light, reveal fade and hazard pulse already applied), B = state (visible: palette offset from world noise/height/glint; remembered: memory amount). The encoding lives in `shaders/world_encoding.gdshaderinc` and keeps every channel at 0.2 or above, because the compat renderer returns values below about 0.2 too low (see test pattern `tools/test_encoding.gd`).
- Global shader params (registered in `project.godot` by `tools/build_project_settings.gd`): `player_pos`, `light_params`, `look_params`, `map_params` (set by `AsciiPostProcess`) and the `reveal_mask` texture (one texel per map cell, owned by `MapReveal`: brightness with reveal overshoot and stagger, seen fraction for memory to seen, glint).
- A `CanvasLayer` (layer 0) holds a full-rect `ColorRect` with `shaders/ascii_post.gdshader`. Per glyph cell it reads the cell centre (`texelFetch`), picks ramp and palette row by id, blends two ramp glyphs as an SDF (`d = mix(sdfA, sdfB, smoothstep(band))`, so any brightness change is a morph, never a swap), colours from the palette LUT and adds own-cell halo, 4-neighbour bloom, wall rim glow, depth of field, vignette and a static dither. Corruption breathes: slow flow-noise warp, noise-picked glyph blend, violet/magenta hue slide.
- `GlyphAtlas` (`scripts/rendering/glyph_atlas.gd`) bakes the shared SDF atlas on the GPU at boot (SubViewport raster at 2x, then `glyph_sdf_bake.gdshader`). It is resolution independent (no rebuild on resize). `shaders/glyph_morph.gdshader` is the reusable canvas shader for overlay glyph quads (task-025).
- Tunables are Resources: `AsciiConfig`, `PaletteConfig` (gradients, baked to a 256x16 LUT), `LightConfig`, `HazardFxConfig`, `RevealConfig`, `GlyphFxConfig`. Pixel sizes scale with `DisplayConfig` (cell 10x14 at 1080p).
- Render settings: no MSAA/FXAA/debanding, no 3D glow, default linear tonemap. `AsciiConfig.enabled = false` shows the raw encoded buffer (debug only).

### Glyph Overlay
- A higher `CanvasLayer` (layer 10+) is NOT processed by the post shader.
- Crisp text glyphs live here:
  - The player's identity glyph(s), positioned each frame by `camera.unproject_position` of the player's 3D position.
  - Narration text.
  - Future in-world menus.
- This is the answer to the task-004 risk (overlay bypass). task-004 records it as a Backlog decision and proves it.

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
