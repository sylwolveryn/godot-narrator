# Visual Direction (M1)

> **Status: superseded 2026-10-30 (decision-002).** The Midnight Neon post-process spec below is no longer the target. It is kept for reference, and its palette ideas may still be reused. A new spec follows the spikes (see the last bullet of Current direction).

## Current direction (decision-002)

- The world is real 3D geometry in an isometric 2.5D view from the very first frame. The old "starts in flat 2D, 2.5D unlocked later" idea is dropped.
- ASCII is a glyph-atlas material on 3D surfaces (walls, floor, objects). Lighting picks the glyph and its brightness. Reference: Illuminascii.
- The full-screen ASCII post-process (task-023/024, SDF "Midnight Neon") is superseded. It stays in the code as legacy until the rebuild.
- "Morph" means a shape built from many glyph objects (batched glyph quads) that fly, rotate and reassemble. It does not mean one glyph blending into another. Reference: Effulgence RPG. Moments: the hero grows into the multi-glyph entity; surroundings lift off and become menu items; narration letters fly in to form a sentence.
- Glow is cheap (additive halo sprites), not full-screen bloom.
- Potato-first: integrated OpenGL 3.3 GPU (Intel HD 2500/4000 class), stable 30+ FPS, Compatibility renderer only. The user tests prototypes on a real low-end laptop.
- Next: two throwaway spikes, Spike A (glyph-material isometric world) and Spike B (glyph-object morph moments). A new spec follows the user's pick from the spikes. Unfinished SDF overlay work (task-025/026) is parked on git branch `parked/sdf-overlay`.
- Unknown: whether the flicker and morph limits in section 6 below carry over. Not decided.

---

## Superseded: Midnight Neon post-process spec

Target look: `docs/art/` moodboards (reference only, never loaded). The midnight-cavern image gives the base: near-black blue, sparse cool glyphs, warm amber light around the hero. The neon-sunset image gives the accents: cyan/green glowing stone, violet corruption, sunset-orange treasure. Dense glyphs read as solid, sparse glyphs read as shadow, and bright glyphs carry a soft halo.

This spec answers the playtest complaint ("dull colours, glyphs change instead of morph, hurts the eyes") with three rules:
1. **Every glyph change is a shape blend.** Nothing pops from one character to another.
2. **Colour comes from gradients.** Never a flat fill.
3. **Nothing animates faster than about 0.5 Hz** unless it is a one-shot event.

### 1. Pipeline (what makes this implementable)

- **World materials are unshaded and encode data, not colour.** Each pixel of the 3D render carries:
  - R = material id (`round(r*15)`)
  - G = luminance 0..1. This already includes player light, reveal fade and hazard pulse, computed from global shader params `player_pos`, `time` and a `reveal_mask` texture with one texel per map cell.
  - B = state. Below 0.5 means visible, and the value carries height/noise. 0.5 or above means remembered.
- **Required render settings:** tonemap Linear, no MSAA/FXAA, no 3D glow.
- **Post shader:** `texelFetch` reads the cell centre, then:
  - picks the glyph ramp and palette row by id
  - draws the glyph from an SDF atlas
  - colours it from a palette LUT (256x16 texture, one row per type, built at boot from `Gradient` resources)
- **Glyph atlas is built at boot:**
  1. Draw the glyphs into a SubViewport (monospace bold, 32 px per glyph).
  2. Run one brute-force SDF pass (spread 4 px).
  3. Store the result as an `ImageTexture`.
- **The overlay (player, narration, death fragments) uses the same SDF atlas** through a `glyph_morph` canvas shader on per-glyph quads. It does not use `Label`, so overlay text can morph too.

### 2. Palette (default set "Midnight Neon")

Colour = `LUT[type](u)`, where `u = L + noise(world_cell * 0.08) * hue_noise_amp + height * height_amp`. Noise is static world-space value noise, never per-frame random. Player light adds a warm tint: `col = mix(col, col * light_tint, light_factor * light_tint_strength)`.

| Element | Shadow | Mid | Highlight | Notes |
|---|---|---|---|---|
| Background | `#030409` (edge) | `#0B1020` (centre) | - | Radial gradient around the player, no glyphs |
| Wall | `#0B2A3A` | `#1F7A8C` | `#5FF2E8` | Noise drifts the hue toward moss `#4BE38A`. Edges near the player get rim glow |
| Floor | `#10162A` | `#2E3A5E` | `#8FA3D9` | Sparse. Warmed by the player light |
| Item | `#7A3E0C` | `#FFB238` | `#FFF1B0` | Emissive |
| Spikes | `#3A0A1A` | `#FF3D5A` | `#FFB08A` | Emissive. Tips burn sunset-orange |
| Corrupting glyph | `#1C0630` | `#9D3CFF` | `#FF4FD8` | Emissive. Hue breathes between violet and magenta |
| Void | `#000000` | - | - | No glyphs (an optional starfield is off by default) |
| Remembered (any type) | `#0A0E1C` | `#24345A` | `#4A5F8F` | Mixed 15% toward the type colour. Density capped. No glow |
| Player light tint | `#FFC27A` | | | Warm amber falloff, as in moodboard 2 |
| Player identity glyph | core `#FFF6E6` | | glow `#FFB347` | Overlay layer |
| Narration base | `#EAF2FF` | | | Glow tint by mood: hum `#FFC98A`, chime `#BFF6FF`, static `#E07BFF`, low_drone `#FF6A4D`, pulse `#7DFFB0` |

**Optional palette sets:** `PaletteConfig` resources can be swapped per run or region. Candidates: "Neon Dusk" (violet background gradient `#1A0B2E`→`#3A1550`, saturated green walls `#39FF7A`) and "Ember Cavern" (slate walls, all-amber highlights). M1 ships the default only, with a `palette_by_run` array left empty.

### 3. Light and depth

| Effect | Rule |
|---|---|
| Player light | Full brightness within `light_inner` cells. Smoothstep down to `light_ambient` at `light_outer`. Lower L produces sparser glyphs, so the density falloff comes for free |
| Glyph halo | Own cell: `glow = emissive * exp(-max(d,0)/glow_radius)` from the SDF distance |
| Cross-cell bloom | Add the emissive of the 4 nearest neighbour cell centres with a Gaussian falloff (`bloom_radius_cells`) |
| Which elements glow | Player, items, spikes, corruption and narration: full glow. Walls: rim glow only, inside the light radius. Floor, remembered cells and void: no glow |
| Vignette | Brightness falloff toward the screen edges (`vignette_strength`). It also lowers L, which thins the glyphs |
| Depth-of-field equivalent | The SDF edge softness grows with distance from the player beyond `dof_start` (`edge_soft_near`→`edge_soft_far`). Colour slides 20% toward the background. In 2.5D, distance from the focal plane is used instead |

### 4. Glyph language

The glyph ramp is per type, ordered sparse to dense, so the type is readable from shape alone. Glyph cell size is 10x14 px at 1080p (192x77 cells), scaled by `ui_scale`.

| Type | Ramp (low → high L) |
|---|---|
| Floor | ` .·:;` |
| Wall | `.:=+*#%@` |
| Item | `.:o*$` |
| Spikes | `.,'^A` |
| Corruption | `.~?§&%` |
| Remembered | Type ramp, capped at `memory_density_cap` (default 0.45 of the ramp) |
| Abstract set (narration/death) | `·`, `-`, `~`, `°`, plus a circle SDF |

### 5. Morphing

**Definition.** A morph is a continuous SDF blend: `d = mix(sdfA, sdfB, ease(t))`, `alpha = smoothstep(0.5-w, 0.5+w, d)`. Mid-morph the glyph scales to 0.92 and gets +15% glow, which sells the motion. Default easing is `easeInOutCubic`.

**Ramp morph (stateless).** `s = L*(N-1)`, `i = floor(s)`, `m = smoothstep(0.5-morph_band, 0.5+morph_band, fract(s))`. The glyph is `mix(sdf[i], sdf[i+1], m)`. Shapes stay crisp for most of the L range and blend only near a step, so any brightness change automatically becomes a morph.

| Trigger | How it morphs | Duration |
|---|---|---|
| Brightness crosses a ramp step | Ramp morph (driven by L) | Follows L |
| Reveal | Mask fades L from 0 to target (`easeOutQuart`, 1.15 overshoot). Staggered by distance from the player | 0.5 s, plus 0.025 s per cell |
| Remembered → seen | B state lerps over the duration: memory LUT → live LUT, density cap lifts | 0.35 s |
| Spike pulse | L = 0.75 ± 0.15 sine at 0.4 Hz, phase from world noise, giving a travelling shimmer | continuous |
| Corruption breathe | See §6 | continuous |
| Erosion, death, narration | See §6 | see §6 |

### 6. Flicker rules and effects

**Hard limits:**
- Ambient cells never change target glyph more than 2 times per second.
- Ambient luminance oscillation stays at or below ±0.25 and at or below 0.5 Hz.
- Non-ramp morphs may cover at most 25% of screen cells at once.
- Ambient animation (corruption, spikes) may cover at most 15% of screen cells at once.
- No full-screen brightness change above 0.4 per event. No flash repeats above 1 Hz.
- No per-frame random in any shader. All variation comes from `time` plus static world noise.
- Hysteresis: L changes from deterministic sources are already smooth. An optional per-cell L smoothing (`l_smoothing_tau`) is listed for a later stateful buffer.

**Corruption breathes, it does not strobe.**
- The glyph UV is domain-warped by slow flow noise (amplitude 0.35 cell, period 3.2 s).
- The glyph SDF blends continuously between two corrupt glyphs, picked by slow noise.
- Hue slides between violet and magenta at 0.3 Hz.
- L breathes ±0.12.

| Effect | Spec |
|---|---|
| Erosion | Identity glyph SDF blends toward a seeded corrupt glyph with `t = erosion` (continuous, plus warp). The corrupt target may change at most every 1.5 s, and only through a morph. Colour lerps `#FFF6E6` → `#B44DFF` and the glow shifts to violet. Above 50% erosion, one fragment glyph is shed every 0.8 s and drifts off over 1 s |
| Death | The identity glyph splits into 10 fragments. Each one flies 1.5 cells outward (ease-out) and morphs identity → abstract (`·` `,` `` ` ``) → empty over 1.2 s, tinted with the killer's colour. The world dims L ×0.4 over 0.8 s. Spikes add one soft +0.3 brightening (0.15 s rise, 0.4 s decay). No strobe |
| Narration in | Each letter starts as an abstract SDF, morphs to the letter over 0.35 s and rises 4 px. Letters start 0.03 s apart, left to right. Glow uses the mood tint |
| Narration out | Reverse: letter → abstract → alpha 0 over 0.5 s, staggered 0.02 s |
| Reveal | Cells grow from darkness through `.` up to their ramp level (see §5) with a cyan glint at 60% progress |

### 7. Tunables (defaults)

| Resource | Field | Default |
|---|---|---|
| AsciiConfig | cell_size | (10, 14) px |
| | atlas_glyph_px / sdf_spread_px | 32 / 4 |
| | morph_band | 0.25 |
| | edge_soft_near / edge_soft_far / dof_start_cells | 0.06 / 0.22 / 8 |
| | glow_radius (SDF units) / glow_strength | 0.35 / 0.8 |
| | bloom_enabled / bloom_radius_cells / bloom_strength | true / 1.2 / 0.5 |
| | vignette_strength / vignette_radius | 0.35 / 0.75 |
| | hue_noise_scale / hue_noise_amp / height_amp | 0.08 / 0.15 / 0.2 |
| | memory_density_cap / memory_type_mix | 0.45 / 0.15 |
| | ramp_floor / wall / item / spikes / corruption | see §4 |
| PaletteConfig | gradients per type, bg_centre / bg_edge, light_tint, palette_by_run | see §2, empty |
| LightConfig | light_inner / light_outer (cells) / light_ambient / light_tint_strength | 6 / 11 / 0.12 / 0.5 |
| RevealConfig | reveal_duration / reveal_stagger_per_cell / reveal_overshoot | 0.5 s / 0.025 s / 1.15 |
| | memory_to_seen_duration | 0.35 s |
| HazardFxConfig | spike_pulse_hz / spike_pulse_amp / spike_base_l | 0.4 / 0.15 / 0.75 |
| | corrupt_warp_amp / corrupt_warp_period / corrupt_hue_hz / corrupt_l_amp | 0.35 cell / 3.2 s / 0.3 / 0.12 |
| GlyphFxConfig | morph_scale_dip / morph_glow_boost / default_ease | 0.92 / 0.15 / IN_OUT_CUBIC |
| | max_glyph_changes_per_sec / max_morph_area / max_ambient_area | 2 / 0.25 / 0.15 |
| | max_flash_delta / max_flash_hz / l_smoothing_tau | 0.4 / 1.0 / 0.12 s |
| | erosion_tint / erosion_retarget_min / erosion_shed_threshold / erosion_shed_interval | `#B44DFF` / 1.5 s / 0.5 / 0.8 s |
| | death_fragments / death_duration / death_spread_cells / death_world_dim / death_dim_time | 10 / 1.2 s / 1.5 / 0.4 / 0.8 s |
| | spike_death_flash / flash_rise / flash_decay | 0.3 / 0.15 s / 0.4 s |
| NarratorConfig | letter_morph_in / letter_stagger_in / letter_rise_px | 0.35 s / 0.03 s / 4 |
| | morph_out / letter_stagger_out | 0.5 s / 0.02 s |
| | text_color / mood_tints | `#EAF2FF` / see §2 |
| PlayerVisualConfig | core_color / glow_color / glow_strength | `#FFF6E6` / `#FFB347` / 1.0 |

### 8. Performance budget (60 FPS, 1920x1080, GTX 1060, gl_compatibility; superseded, see banner)

| Item | Budget | Cheaper fallback |
|---|---|---|
| 3D world (unshaded, encoded) | ≤ 2 ms | - |
| Post shader: 1 cell fetch + 2 atlas samples + LUT | ≤ 1.0 ms | - |
| Cross-cell bloom (4 extra fetches per pixel) | ≤ 0.6 ms | `bloom_enabled = false`: own-cell SDF halo only |
| Corruption flow noise (ALU) | ≤ 0.3 ms | 64x64 noise texture lookup |
| Overlay glyph quads (≤ 200 with morph shader) | ≤ 0.5 ms | Cap fragments to 6 |
| SDF atlas bake (one-off at boot) | < 50 ms | Bake offline with a `tools/` script into `resources/` |
| SDF corner rounding at 32 px | quality risk | Raise the atlas to 48 px, or use MSDF later |

Total target: at most 5 ms GPU, which leaves headroom. **Risk:** sRGB conversion of the encoded R/B channels. Decode ids with a rounding tolerance and verify them with a test pattern on the first implementation.
