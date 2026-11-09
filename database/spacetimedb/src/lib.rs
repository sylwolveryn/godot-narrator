//! Narrator data module (TASK-046).
//!
//! Editable lookup tables (events, languages, narration file paths, glyph
//! animation tuning) plus player track records. The Godot client talks to this
//! module over the plain HTTP API (SQL + reducer calls), so table, column and
//! reducer names are a public contract: do not rename them without updating
//! the game.

use spacetimedb::{ReducerContext, Table, Timestamp};

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

/// A narration event id the game can raise (e.g. "DEATH_BY_SPIKES").
#[spacetimedb::table(accessor = event_def, public)]
pub struct EventDef {
    #[primary_key]
    pub id: String,
    pub description: String,
}

/// A narration language id (e.g. "EN_GB") with a display name, and the stand-ins its narration is obfuscated with
/// while it is not understood (TASK-100). Glyph pools: any single code points; empty = the game's defaults.
/// `static_glyphs`: the stable first stand-ins (understanding below obf_spin_start), `wild_glyphs`: the spinning ones,
/// `foreign_chance`: 0..1 share of stand-ins taken from the shared other-alphabet pool instead, `font`: res:// path of
/// a font the stand-ins are drawn with (empty = the narration font).
#[spacetimedb::table(accessor = language_def, public)]
pub struct LanguageDef {
    #[primary_key]
    pub id: String,
    pub name: String,
    #[default("")]
    pub static_glyphs: String,
    #[default("")]
    pub wild_glyphs: String,
    #[default(0.0)]
    pub foreign_chance: f32,
    #[default("")]
    pub font: String,
}

/// One row per (event, language): file paths and how often it played.
#[spacetimedb::table(accessor = narration, public)]
pub struct Narration {
    #[primary_key]
    #[auto_inc]
    pub id: u64,
    #[index(btree)]
    pub event: String,
    pub language: String,
    pub triggered: u64,
    pub text_path: String,
    pub sound_path: String,
}

/// Aggregate player track record. Single row, id = 1.
#[spacetimedb::table(accessor = player_stats, public)]
pub struct PlayerStats {
    #[primary_key]
    pub id: u32,
    pub played_seconds: f64,
    pub steps: u64,
    pub transformations: u64,
    pub deaths: u64,
}

/// Death count per cause.
#[spacetimedb::table(accessor = player_death, public)]
pub struct PlayerDeath {
    #[primary_key]
    pub cause: String,
    pub count: u64,
}

/// How well the player understands a language, percent 0..100.
/// `max`: top limit of the understanding when set (>= 0); NO_LANGUAGE_MAX (-1) = no limit. A value over the limit is
/// brought down to it (by the game and by set_language_understanding).
#[spacetimedb::table(accessor = player_language, public)]
pub struct PlayerLanguage {
    #[primary_key]
    pub language: String,
    pub understanding: f32,
    #[default(-1.0)]
    pub max: f32,
}

/// Things the player consumed, by kind ("dirt", "diamond", ...): count ever.
#[spacetimedb::table(accessor = player_consumed, public)]
pub struct PlayerConsumed {
    #[primary_key]
    pub kind: String,
    pub count: u64,
}

/// Narration files the game tried to load but could not find.
#[spacetimedb::table(accessor = missing_narration, public)]
pub struct MissingNarration {
    #[primary_key]
    pub key: String,
    pub first_seen: Timestamp,
}

/// Player movement tuning per profile: "default" (fallback), "single" (the small
/// one-glyph form) and "grown" (the multi-glyph entity). The game picks the row of
/// the active form and falls back to "default".
#[spacetimedb::table(accessor = movement_profile, public)]
pub struct MovementProfile {
    #[primary_key]
    pub profile: String,
    /// Top speed, world units per second.
    pub max_speed: f32,
    /// Speed gained per second while input is held (units/s^2).
    pub acceleration: f32,
    /// Speed lost per second when input stops (units/s^2).
    pub deceleration: f32,
    /// Sprint (task-063): top speed multiplier while sprint is held.
    #[default(1.5)]
    pub sprint_speed_mult: f32,
    /// Sprint: acceleration multiplier while sprint is held.
    #[default(2.0)]
    pub sprint_accel_mult: f32,
    /// Sprint: deceleration multiplier after a sprint until the body stops (< 1 glides).
    #[default(0.45)]
    pub sprint_decel_mult: f32,
}

/// Look and feel of the player avatar (one row per profile; the game reads "default").
/// Crystal glow: the glyph slowly shifts through `crystal_palette` per facet.
/// Ink trail: glyphs from `trail_chars` dropped every `trail_spacing` world units,
/// fading over `trail_lifetime` seconds. Lean / stretch: the avatar leans into its
/// motion and stretches when speeding up, squashes when braking.
#[spacetimedb::table(accessor = avatar_fx, public)]
pub struct AvatarFx {
    #[primary_key]
    pub profile: String,
    /// Comma separated hex colours "#rrggbb,...".
    pub crystal_palette: String,
    /// Palette cycles per second (slow: 0.05..0.2).
    pub crystal_speed: f32,
    /// Share of the crystal colour mixed into the glyph and its halo (0..1).
    pub crystal_strength: f32,
    /// Facets across the glyph (each facet has its own phase).
    pub crystal_facets: f32,
    /// Share of facets that briefly sparkle (0..1, keep small).
    pub crystal_sparkle: f32,
    pub trail_enabled: bool,
    /// Characters the trail drops (one picked per drop).
    pub trail_chars: String,
    /// Ink colour and the faint luminous rim around it ("#rrggbb").
    pub trail_color: String,
    pub trail_rim: String,
    /// Seconds a drop takes to fade out.
    pub trail_lifetime: f32,
    /// World units travelled between two drops.
    pub trail_spacing: f32,
    /// Drop half-size in world units, and how much it spreads (grows) while fading.
    pub trail_size: f32,
    pub trail_spread: f32,
    /// Sideways random offset of a drop, world units.
    pub trail_jitter: f32,
    /// Lean into the motion (screen-space shear at full speed).
    pub lean_amount: f32,
    /// Stretch when speeding up / squash when braking (fraction of the height).
    pub stretch_amount: f32,
    /// Seconds the lean / stretch takes to follow the motion.
    pub feel_smoothing: f32,
}

/// (profile, max_speed, acceleration, deceleration)
/// (profile, max_speed, acceleration, deceleration, sprint_speed_mult, sprint_accel_mult, sprint_decel_mult)
const SEED_MOVEMENT: &[(&str, f32, f32, f32, f32, f32, f32)] = &[
    ("default", 4.5, 14.0, 16.0, 1.5, 2.0, 0.45),
    ("single", 4.8, 22.0, 24.0, 1.5, 2.0, 0.45),
    ("grown", 5.3, 8.0, 10.0, 1.5, 2.0, 0.45),
];

/// Crafting recipes (task-088): learned one by one through Research in the order of `research_order`; research and
/// crafting spend the player's dirt. `label` is what the menu shows (lowercase reads best as glyphs).
#[spacetimedb::table(accessor = craft_def, public)]
pub struct CraftDef {
    #[primary_key]
    pub id: String,
    pub label: String,
    pub research_order: u32,
    pub research_cost: u32,
    pub craft_cost: u32,
}

const SEED_CRAFTS: &[(&str, &str, u32, u32, u32)] = &[
    ("dust_lens", "dust lens", 1, 20, 10),
    ("clay_sigil", "clay sigil", 2, 40, 15),
    ("mud_bell", "mud bell", 3, 80, 25),
    ("soil_heart", "soil heart", 4, 150, 50),
    ("grave_seed", "grave seed", 5, 300, 100),
];

/// Base glyph ramp per surface (task-079): the characters the glyph-surface shader draws, from sparse to dense
/// (the blank is implicit). Split into grapheme clusters by the game and spread over the atlas density columns.
/// Surfaces: "wall", "floor", "spikes", "corruption", "item", "dirt".
#[spacetimedb::table(accessor = glyph_ramp, public)]
pub struct GlyphRamp {
    #[primary_key]
    pub surface: String,
    pub chars: String,
}

const SEED_RAMPS: &[(&str, &str)] = &[
    ("wall", ".:+xX#M"),
    ("floor", ".,:;+o0"),
    ("spikes", "'^!AVW#"),
    ("corruption", "`~?%&$#"),
    ("item", "1l0I|8B"),
    ("dirt", ".,:;o%&"),
];

/// Proximity glyph animation tuning per surface
/// ("wall", "floor", "spikes", "corruption", "item").
#[spacetimedb::table(accessor = glyph_anim, public)]
pub struct GlyphAnim {
    #[primary_key]
    pub surface: String,
    pub enabled: bool,
    /// Characters to cycle; each char is one glyph.
    pub chars: String,
    /// Comma separated hex colours "#rrggbb,...".
    pub palette: String,
    /// Share of glyphs animating at distance 0 (0..1).
    pub near_intensity: f32,
    /// Share of glyphs animating at `radius` and beyond (0..1).
    pub far_intensity: f32,
    /// Radius in map cells.
    pub radius: f32,
    /// Glyph changes per second.
    pub char_speed: f32,
    /// Palette cycles per second.
    pub color_speed: f32,
}

/// Visibility rules per map (task-069). `map_id` = map file name without extension
/// (e.g. "m3_dirt"). A map without a row plays with the game's config defaults
/// (fog on, darkness on, limited reveal radius with line of sight). Negative
/// numbers also mean "use the game's default".
#[spacetimedb::table(accessor = map_settings, public)]
pub struct MapSettings {
    #[primary_key]
    pub map_id: String,
    /// Every drawn cell is seen from the start of each run (live look, no memory look).
    pub reveal_all: bool,
    /// Depth fog: the far side of the screen darkens, ambient fades with distance.
    pub fog_enabled: bool,
    /// Unlit surroundings; false = full light everywhere, no memory dimming.
    pub darkness_enabled: bool,
    /// Cells around the player that get revealed (< 0 = game default 5.5).
    pub reveal_radius: f32,
    /// Walls, items and dirt hide what lies behind them.
    pub line_of_sight: bool,
    /// Player light radius in world units (< 0 = game default 11).
    pub player_light_radius: f32,
    /// Light level of unlit surfaces 0..1.5 (< 0 = game default; wins over darkness_enabled).
    pub ambient_level: f32,
}

/// (map_id, reveal_all, fog_enabled, darkness_enabled, reveal_radius, line_of_sight, player_light_radius, ambient_level)
const SEED_MAP_SETTINGS: &[(&str, bool, bool, bool, f32, bool, f32, f32)] = &[
    ("m3_dirt", true, false, false, -1.0, true, -1.0, -1.0),
];

/// Enemy types (task-075/076), key `kind` (crawler, hunter, wanderer). A kind without a row plays with the game's
/// config defaults (resources/config/enemy_config.tres).
#[spacetimedb::table(accessor = enemy_def, public)]
pub struct EnemyDef {
    #[primary_key]
    pub kind: String,
    /// Cells per second.
    pub speed: f32,
    /// Touching the player ends the run.
    pub lethal: bool,
    /// Hunter: seconds between path searches.
    pub repath_seconds: f32,
    /// Hunter: search window around it in cells; a player outside it is not hunted.
    pub search_radius: i32,
    /// Wanderer: chance (0..1) to re-roll the direction at a junction.
    pub turn_chance: f32,
    /// Wanderer: straight run length range in cells before it re-rolls.
    pub run_min: i32,
    pub run_max: i32,
    /// Diamonds it bursts into when destroyed.
    pub diamonds: i32,
    /// Leaves a black hole on its cell when destroyed.
    pub black_hole: bool,
}

/// (kind, speed, lethal, repath_seconds, search_radius, turn_chance, run_min, run_max, diamonds, black_hole)
const SEED_ENEMIES: &[(&str, f32, bool, f32, i32, f32, i32, i32, i32, bool)] = &[
    ("crawler", 2.2, true, 0.6, 16, 0.35, 3, 9, 3, false),
    ("hunter", 2.6, true, 0.6, 16, 0.35, 3, 9, 0, true),
    ("wanderer", 1.8, true, 0.6, 16, 0.35, 3, 9, 2, false),
];

/// Death splat size per entity form (task-104), key `profile`: "default" (fallback for a form without a row), then
/// the forms ("single", "grown" = the many form, "brain"). A death sprays a random radius in [radius_min, radius_max]
/// tiles around the death cell.
#[spacetimedb::table(accessor = death_splat, public)]
pub struct DeathSplat {
    #[primary_key]
    pub profile: String,
    /// Smallest splat radius, tiles.
    pub radius_min: f32,
    /// Largest splat radius, tiles.
    pub radius_max: f32,
}

/// (profile, radius_min, radius_max)
const SEED_DEATH_SPLAT: &[(&str, f32, f32)] = &[
    ("default", 2.0, 4.0),
    ("brain", 4.0, 6.0),
    ("grown", 4.0, 8.0),
];

/// Bumped to tell running games to reload their tables. Single row, id = 1.
#[spacetimedb::table(accessor = config_version, public)]
pub struct ConfigVersion {
    #[primary_key]
    pub id: u32,
    pub version: u64,
}

// ---------------------------------------------------------------------------
// Seed data
// ---------------------------------------------------------------------------

const SINGLETON_ID: u32 = 1;
const FULL_UNDERSTANDING: f32 = 100.0;
/// A new game starts with no understanding of any language (task-065); the game pushes its saved values on load.
const SEED_UNDERSTANDING: f32 = 0.0;
/// player_language.max meaning "no limit".
const NO_LANGUAGE_MAX: f32 = -1.0;

const SEED_EVENTS: &[(&str, &str)] = &[
    ("RUN_STARTED", "A new run begins"),
    ("FIRST_MOVE", "The player moves for the first time in a run"),
    ("IDLE_FOR_SHORT", "The player has been idle for a short while"),
    ("IDLE_FOR_MID", "The player has been idle for a while"),
    ("IDLE_FOR_LONG", "The player has been idle for a long time"),
    ("WALL_REVEALED", "A wall is revealed"),
    ("ITEM_REVEALED", "An item is revealed"),
    ("SPIKES_REVEALED", "Spikes are revealed"),
    ("CORRUPTION_ENTERED", "The player steps into corruption"),
    ("EROSION_HIGH", "Erosion reaches a high level"),
    ("HIT_WALL", "The player bumps into a wall"),
    ("HIT_UNKNOWN", "The player bumps into something unknown"),
    ("HIT_SPIKES", "The player steps on spikes"),
    ("DEATH", "The player dies"),
    ("DEATH_BY_SPIKES", "The player dies on spikes"),
    ("DEATH_BY_CORRUPTION", "The player dies to corruption"),
    ("TRANSFORMED", "Any chosen entity form switch; fallback for TRANSFORMED_TO_ONE/MANY"),
    ("TRANSFORMED_TO_ONE", "The player transforms into the one"),
    ("TRANSFORMED_TO_MANY", "The player transforms into the many"),
    ("ORIGIN_STRUCK", "The origin is struck"),
    ("ORIGIN_RECANTED", "The origin is recanted"),
    ("TIME", "Time passes"),
    ("SPRINT_UNLOCKED", "First move of a run once sprint is available"),
    ("WALL_EATEN", "The player eats a dirt wall"),
    ("WALLS_DEVOURED", "The eaten dirt walls reach the next random milestone"),
    ("DEATH_BY_ENEMY", "The player dies touching an enemy"),
    ("BLACK_HOLE_FORMED", "A destroyed hunter collapses into a black hole"),
    ("DIAMOND_FOUND", "The player picks up a diamond"),
    ("MANY_FIRED_CANNON", "The many form fires a cannon"),
    ("FOUNTAIN_WHISPER", "Near a gargoyle fountain with a language other than English (and not DREAM) selected"),
    ("FOUNTAIN_SECRET", "Near a gargoyle fountain with DREAM selected: the fountain's own message"),
    ("TELEPORT_DEPARTED", "The player steps into a teleport and leaves"),
    ("TELEPORT_ARRIVED", "The player arrives on a teleport pad"),
    ("ENEMY_DESTROYED", "An enemy is destroyed"),
    ("CANNON_FIRED", "A cannon fires (single form)"),
    ("MENU_ITEM_NEW", "The in-world menu offers something the player has not seen yet"),
    ("RESEARCH_DONE", "Research in the crafting menu spends dirt and teaches a new craft"),
    ("CRAFT_LEARNED", "A new craft is known"),
    ("CRAFTED", "Something is crafted from dirt"),
    ("CRAFT_REFUSED", "Research or a craft needs more dirt than the player has"),
    ("FORM_BLOCKED", "Switching to the many form is refused: the grown body does not fit here"),
    ("BRAIN_UNLOCKED", "A map was fully discovered and two teleports were made: the brain form is offered"),
    ("TRANSFORMED_TO_BRAIN", "The player becomes the brain"),
    ("BRAIN_LANGUAGE_SHIFT", "The brain changes the language with the interact button"),
];

/// (id, name, static_glyphs, wild_glyphs, foreign_chance, font).
const SEED_LANGUAGES: &[(&str, &str, &str, &str, f32, &str)] = &[
    ("EN_GB", "English (GB)", "øØþÞðÐßæÆŋ¤§", "#@%&{}<>~^?!ƒ¥£€¶†‡ÆŒøþ", 0.08, ""),
    ("HU_HU", "Hungarian", "őŐűŰöüÖÜ", "őűöüáéíóúŐŰÖÜÁÉÍÓÚ#%&@", 0.08, ""),
    ("ALIEN", "Alien", "⏃⏚⎎⍜⟟⌰⋔", "⏃⏚☊⎅⟒⎎☌⊑⟟⟊☍⌰⋔⋏⍜⌿⍾⍀⌇⏁⎍⎐⍙⌖⊬⋉⍟҉ʘ", 0.1, ""),
    ("MATRIX", "Matrix", "ｱｶｻﾀﾅ01한ا字", "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎ0123456789日月字書夢光闇한글사랑마음빛꿈ابتثجحخدذرزسشصضطظعغ#@%&$*+=<>{}[]|/~^💀👁🔥🌀⚡☢☣✦✧◊", 0.0, ""),
    ("DREAM", "Dream", "ꔅꔆꔚꔛꔣꕀꕁꕢꕣꕤꖘꖜꗁꗂꗬꗢꘐꘚ", "ꔅꔆꔚꔛꔣꕀꕁꕢꕣꕤꖘꖜꗁꗂꗬꗢꘐꘚꔂꔌꔓꔧꔬꔲꕆꕊꕋꕥꕩꕹꕺꕻꖉꖒꖴꖻꖼꗈꗤꗥꗪꗮꗯꗴꗶꘈꘒ꘏꘠꘣꘨꘩ꔞꔸꔹꔺ∿≋◎⊙", 0.03, "res://assets/fonts/dream/NotoSansVai-Regular.ttf"),
    ("DE_DE", "German", "äöüßÄÖÜẞ", "äöüßÄÖÜẞ€§#%&@ſ", 0.08, ""),
    ("RU_RU", "Russian", "жшщъыэюяЖШЩЪЫЭЮЯ", "абвгдеёжзийклмнопрстуфхцчшщъыьэюяБГДЖЗИЙЛПФЦЧШЩЪЫЬЭЮЯ", 0.05, ""),
    ("JP_HAN", "Japanese (Kanji)", "字書夢光闇気心言葉語", "日月火水木金土山川人口目耳手足心言語書字夢光闇気雨雲風星空花鳥魚", 0.05, ""),
    ("JP_KANA", "Japanese (Kana)", "あいうえおかきくけこ", "あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをんアイウエオカキクケコサシスセソタチツテトナニヌネノ", 0.05, ""),
];

struct GlyphSeed {
    surface: &'static str,
    enabled: bool,
    chars: &'static str,
    palette: &'static str,
    near_intensity: f32,
    far_intensity: f32,
    radius: f32,
    char_speed: f32,
    color_speed: f32,
}

const SEED_GLYPHS: &[GlyphSeed] = &[
    GlyphSeed {
        surface: "floor",
        enabled: true,
        chars: ".,:;+o0",
        palette: "#5a5a7a,#ffbd70,#ff8c5a,#b48cff",
        near_intensity: 0.55,
        far_intensity: 0.06,
        radius: 6.0,
        char_speed: 2.5,
        color_speed: 0.25,
    },
    GlyphSeed {
        surface: "wall",
        enabled: true,
        chars: ".:+xX",
        palette: "#4a5f8a,#9fc2ff",
        near_intensity: 0.12,
        far_intensity: 0.0,
        radius: 4.0,
        char_speed: 1.5,
        color_speed: 0.15,
    },
    GlyphSeed {
        surface: "spikes",
        enabled: true,
        chars: "'^!AV",
        palette: "#ff6a3a,#ffb07a",
        near_intensity: 0.4,
        far_intensity: 0.1,
        radius: 5.0,
        char_speed: 3.0,
        color_speed: 0.4,
    },
    GlyphSeed {
        surface: "corruption",
        enabled: true,
        chars: "`~?%&$",
        palette: "#8c47ff,#ff47bf,#47e0ff",
        near_intensity: 0.6,
        far_intensity: 0.25,
        radius: 6.0,
        char_speed: 4.0,
        color_speed: 0.5,
    },
    GlyphSeed {
        surface: "item",
        enabled: false,
        chars: "1l0I|",
        palette: "#bff7ff,#40a6ff",
        near_intensity: 0.2,
        far_intensity: 0.0,
        radius: 3.0,
        char_speed: 1.0,
        color_speed: 0.2,
    },
];

fn text_path(event: &str, language: &str) -> String {
    format!("narration/event/{event}_{language}.json")
}

fn sound_path(event: &str, language: &str) -> String {
    format!("narration/event/{event}_{language}.mp3")
}

fn find_narration(ctx: &ReducerContext, event: &str, language: &str) -> Option<Narration> {
    ctx.db
        .narration()
        .event()
        .filter(&event.to_string())
        .find(|row| row.language == language)
}

fn insert_default_narration(ctx: &ReducerContext, event: &str, language: &str) -> Narration {
    ctx.db.narration().insert(Narration {
        id: 0,
        event: event.to_string(),
        language: language.to_string(),
        triggered: 0,
        text_path: text_path(event, language),
        sound_path: sound_path(event, language),
    })
}

/// Inserts every missing seed row. Never overwrites existing rows.
fn seed(ctx: &ReducerContext) {
    for (id, description) in SEED_EVENTS {
        if ctx.db.event_def().id().find(id.to_string()).is_none() {
            ctx.db.event_def().insert(EventDef {
                id: id.to_string(),
                description: description.to_string(),
            });
        }
    }
    for (id, name, static_glyphs, wild_glyphs, foreign_chance, font) in SEED_LANGUAGES {
        let seeded = LanguageDef {
            id: id.to_string(),
            name: name.to_string(),
            static_glyphs: static_glyphs.to_string(),
            wild_glyphs: wild_glyphs.to_string(),
            foreign_chance: *foreign_chance,
            font: font.to_string(),
        };
        match ctx.db.language_def().id().find(id.to_string()) {
            None => {
                ctx.db.language_def().insert(seeded);
            }
            // Rows from before the glyph columns (all empty): fill in the seeded pools, keep the name.
            Some(row) if row.static_glyphs.is_empty() && row.wild_glyphs.is_empty() && row.font.is_empty() => {
                ctx.db.language_def().id().update(LanguageDef { name: row.name, ..seeded });
            }
            Some(_) => {}
        }
        if ctx.db.player_language().language().find(id.to_string()).is_none() {
            let understanding = SEED_UNDERSTANDING;
            ctx.db.player_language().insert(PlayerLanguage {
                language: id.to_string(),
                understanding,
                max: NO_LANGUAGE_MAX,
            });
        }
    }
    // Narration rows for every event x language currently defined (seeded or added later).
    let events: Vec<String> = ctx.db.event_def().iter().map(|e| e.id).collect();
    let languages: Vec<String> = ctx.db.language_def().iter().map(|l| l.id).collect();
    for event in &events {
        for language in &languages {
            if find_narration(ctx, event, language).is_none() {
                insert_default_narration(ctx, event, language);
            }
        }
    }
    for (id, label, order, research_cost, craft_cost) in SEED_CRAFTS {
        if ctx.db.craft_def().id().find(id.to_string()).is_none() {
            ctx.db.craft_def().insert(CraftDef {
                id: id.to_string(),
                label: label.to_string(),
                research_order: *order,
                research_cost: *research_cost,
                craft_cost: *craft_cost,
            });
        }
    }
    for (surface, chars) in SEED_RAMPS {
        if ctx.db.glyph_ramp().surface().find(surface.to_string()).is_none() {
            ctx.db.glyph_ramp().insert(GlyphRamp { surface: surface.to_string(), chars: chars.to_string() });
        }
    }
    for g in SEED_GLYPHS {
        if ctx.db.glyph_anim().surface().find(g.surface.to_string()).is_none() {
            ctx.db.glyph_anim().insert(GlyphAnim {
                surface: g.surface.to_string(),
                enabled: g.enabled,
                chars: g.chars.to_string(),
                palette: g.palette.to_string(),
                near_intensity: g.near_intensity,
                far_intensity: g.far_intensity,
                radius: g.radius,
                char_speed: g.char_speed,
                color_speed: g.color_speed,
            });
        }
    }
    for (profile, max_speed, acceleration, deceleration, sprint_speed, sprint_accel, sprint_decel) in SEED_MOVEMENT {
        if ctx.db.movement_profile().profile().find(profile.to_string()).is_none() {
            ctx.db.movement_profile().insert(MovementProfile {
                profile: profile.to_string(),
                max_speed: *max_speed,
                acceleration: *acceleration,
                deceleration: *deceleration,
                sprint_speed_mult: *sprint_speed,
                sprint_accel_mult: *sprint_accel,
                sprint_decel_mult: *sprint_decel,
            });
        }
    }
    for (map_id, reveal_all, fog, dark, radius, sight, light, ambient) in SEED_MAP_SETTINGS {
        if ctx.db.map_settings().map_id().find(map_id.to_string()).is_none() {
            ctx.db.map_settings().insert(MapSettings {
                map_id: map_id.to_string(),
                reveal_all: *reveal_all,
                fog_enabled: *fog,
                darkness_enabled: *dark,
                reveal_radius: *radius,
                line_of_sight: *sight,
                player_light_radius: *light,
                ambient_level: *ambient,
            });
        }
    }
    for (kind, speed, lethal, repath, radius, turn, run_min, run_max, diamonds, hole) in SEED_ENEMIES {
        if ctx.db.enemy_def().kind().find(kind.to_string()).is_none() {
            ctx.db.enemy_def().insert(EnemyDef {
                kind: kind.to_string(),
                speed: *speed,
                lethal: *lethal,
                repath_seconds: *repath,
                search_radius: *radius,
                turn_chance: *turn,
                run_min: *run_min,
                run_max: *run_max,
                diamonds: *diamonds,
                black_hole: *hole,
            });
        }
    }
    for (profile, radius_min, radius_max) in SEED_DEATH_SPLAT {
        if ctx.db.death_splat().profile().find(profile.to_string()).is_none() {
            ctx.db.death_splat().insert(DeathSplat {
                profile: profile.to_string(),
                radius_min: *radius_min,
                radius_max: *radius_max,
            });
        }
    }
    if ctx.db.avatar_fx().profile().find("default".to_string()).is_none() {
        ctx.db.avatar_fx().insert(default_avatar_fx());
    }
    if ctx.db.player_stats().id().find(SINGLETON_ID).is_none() {
        ctx.db.player_stats().insert(PlayerStats {
            id: SINGLETON_ID,
            played_seconds: 0.0,
            steps: 0,
            transformations: 0,
            deaths: 0,
        });
    }
    if ctx.db.config_version().id().find(SINGLETON_ID).is_none() {
        ctx.db.config_version().insert(ConfigVersion { id: SINGLETON_ID, version: 1 });
    }
}

fn stats_row(ctx: &ReducerContext) -> PlayerStats {
    match ctx.db.player_stats().id().find(SINGLETON_ID) {
        Some(row) => row,
        None => ctx.db.player_stats().insert(PlayerStats {
            id: SINGLETON_ID,
            played_seconds: 0.0,
            steps: 0,
            transformations: 0,
            deaths: 0,
        }),
    }
}

// ---------------------------------------------------------------------------
// Reducers
// ---------------------------------------------------------------------------

#[spacetimedb::reducer(init)]
pub fn init(ctx: &ReducerContext) {
    seed(ctx);
}

/// Idempotent: inserts only rows that are missing. Safe to re-run after
/// adding new events or languages.
#[spacetimedb::reducer]
pub fn seed_defaults(ctx: &ReducerContext) {
    seed(ctx);
}

/// Wipes the lookup tables (not player tables) and re-seeds them.
#[spacetimedb::reducer]
pub fn reset_defaults(ctx: &ReducerContext) {
    let ids: Vec<String> = ctx.db.event_def().iter().map(|r| r.id).collect();
    for id in ids {
        ctx.db.event_def().id().delete(id);
    }
    let ids: Vec<String> = ctx.db.language_def().iter().map(|r| r.id).collect();
    for id in ids {
        ctx.db.language_def().id().delete(id);
    }
    let ids: Vec<u64> = ctx.db.narration().iter().map(|r| r.id).collect();
    for id in ids {
        ctx.db.narration().id().delete(id);
    }
    let ids: Vec<String> = ctx.db.glyph_anim().iter().map(|r| r.surface).collect();
    for id in ids {
        ctx.db.glyph_anim().surface().delete(id);
    }
    let ids: Vec<String> = ctx.db.movement_profile().iter().map(|r| r.profile).collect();
    for id in ids {
        ctx.db.movement_profile().profile().delete(id);
    }
    let ids: Vec<String> = ctx.db.avatar_fx().iter().map(|r| r.profile).collect();
    for id in ids {
        ctx.db.avatar_fx().profile().delete(id);
    }
    let ids: Vec<String> = ctx.db.map_settings().iter().map(|r| r.map_id).collect();
    for id in ids {
        ctx.db.map_settings().map_id().delete(id);
    }
    let ids: Vec<String> = ctx.db.enemy_def().iter().map(|r| r.kind).collect();
    for id in ids {
        ctx.db.enemy_def().kind().delete(id);
    }
    let ids: Vec<String> = ctx.db.death_splat().iter().map(|r| r.profile).collect();
    for id in ids {
        ctx.db.death_splat().profile().delete(id);
    }
    seed(ctx);
}

#[spacetimedb::reducer]
pub fn narration_triggered(ctx: &ReducerContext, event: String, language: String) {
    let row = match find_narration(ctx, &event, &language) {
        Some(row) => row,
        None => insert_default_narration(ctx, &event, &language),
    };
    ctx.db.narration().id().update(Narration { triggered: row.triggered + 1, ..row });
}

#[spacetimedb::reducer]
pub fn add_play_stats(ctx: &ReducerContext, seconds: f64, steps: u64, transformations: u64) {
    let row = stats_row(ctx);
    ctx.db.player_stats().id().update(PlayerStats {
        played_seconds: row.played_seconds + seconds.max(0.0),
        steps: row.steps + steps,
        transformations: row.transformations + transformations,
        ..row
    });
}

#[spacetimedb::reducer]
pub fn record_death(ctx: &ReducerContext, cause: String) {
    let row = stats_row(ctx);
    ctx.db.player_stats().id().update(PlayerStats { deaths: row.deaths + 1, ..row });
    match ctx.db.player_death().cause().find(&cause) {
        Some(death) => {
            ctx.db.player_death().cause().update(PlayerDeath { count: death.count + 1, ..death });
        }
        None => {
            ctx.db.player_death().insert(PlayerDeath { cause, count: 1 });
        }
    }
}

#[spacetimedb::reducer]
pub fn set_language_understanding(ctx: &ReducerContext, language: String, understanding: f32) {
    let existing = ctx.db.player_language().language().find(&language);
    let max = existing.as_ref().map(|r| r.max).unwrap_or(NO_LANGUAGE_MAX);
    let top = if max >= 0.0 { max.min(FULL_UNDERSTANDING) } else { FULL_UNDERSTANDING };
    let value = if understanding.is_nan() { 0.0 } else { understanding.clamp(0.0, top) };
    let row = PlayerLanguage { language, understanding: value, max };
    if existing.is_some() {
        ctx.db.player_language().language().update(row);
    } else {
        ctx.db.player_language().insert(row);
    }
}

/// Adds `amount` to the consumed count of `kind` (creates the row if missing).
#[spacetimedb::reducer]
pub fn record_consumed(ctx: &ReducerContext, kind: String, amount: u64) {
    match ctx.db.player_consumed().kind().find(&kind) {
        Some(row) => {
            ctx.db.player_consumed().kind().update(PlayerConsumed { count: row.count + amount, ..row });
        }
        None => {
            ctx.db.player_consumed().insert(PlayerConsumed { kind, count: amount });
        }
    }
}

/// Duplicates are silently ignored (first_seen keeps the first report).
#[spacetimedb::reducer]
pub fn report_missing(ctx: &ReducerContext, key: String) {
    if ctx.db.missing_narration().key().find(&key).is_none() {
        ctx.db.missing_narration().insert(MissingNarration { key, first_seen: ctx.timestamp });
    }
}

#[spacetimedb::reducer]
pub fn clear_missing(ctx: &ReducerContext) {
    let keys: Vec<String> = ctx.db.missing_narration().iter().map(|r| r.key).collect();
    for key in keys {
        ctx.db.missing_narration().key().delete(key);
    }
}

#[spacetimedb::reducer]
pub fn bump_config_version(ctx: &ReducerContext) {
    match ctx.db.config_version().id().find(SINGLETON_ID) {
        Some(row) => {
            ctx.db.config_version().id().update(ConfigVersion { version: row.version + 1, ..row });
        }
        None => {
            ctx.db.config_version().insert(ConfigVersion { id: SINGLETON_ID, version: 1 });
        }
    }
}

#[spacetimedb::reducer]
#[allow(clippy::too_many_arguments)]
pub fn upsert_glyph_anim(
    ctx: &ReducerContext,
    surface: String,
    enabled: bool,
    chars: String,
    palette: String,
    near_intensity: f32,
    far_intensity: f32,
    radius: f32,
    char_speed: f32,
    color_speed: f32,
) {
    let row = GlyphAnim {
        surface,
        enabled,
        chars,
        palette,
        near_intensity: near_intensity.clamp(0.0, 1.0),
        far_intensity: far_intensity.clamp(0.0, 1.0),
        radius: radius.max(0.0),
        char_speed: char_speed.max(0.0),
        color_speed: color_speed.max(0.0),
    };
    if ctx.db.glyph_anim().surface().find(&row.surface).is_some() {
        ctx.db.glyph_anim().surface().update(row);
    } else {
        ctx.db.glyph_anim().insert(row);
    }
}

/// Sets one movement profile; also bumps the config version so a running game
/// picks the change up on its next poll.
#[spacetimedb::reducer]
pub fn upsert_movement_profile(
    ctx: &ReducerContext,
    profile: String,
    max_speed: f32,
    acceleration: f32,
    deceleration: f32,
) {
    // Sprint multipliers are not edited here (the god window sends 4 values): keep the stored ones.
    let existing = ctx.db.movement_profile().profile().find(&profile);
    let sprint = |pick: fn(&MovementProfile) -> f32, seed: fn(&(&str, f32, f32, f32, f32, f32, f32)) -> f32| -> f32 {
        match &existing {
            Some(r) => pick(r),
            None => SEED_MOVEMENT.iter().find(|s| s.0 == "default").map(seed).unwrap_or(1.0),
        }
    };
    let row = MovementProfile {
        sprint_speed_mult: sprint(|r| r.sprint_speed_mult, |s| s.4),
        sprint_accel_mult: sprint(|r| r.sprint_accel_mult, |s| s.5),
        sprint_decel_mult: sprint(|r| r.sprint_decel_mult, |s| s.6),
        profile,
        max_speed: max_speed.max(0.0),
        acceleration: acceleration.max(0.01),
        deceleration: deceleration.max(0.01),
    };
    if ctx.db.movement_profile().profile().find(&row.profile).is_some() {
        ctx.db.movement_profile().profile().update(row);
    } else {
        ctx.db.movement_profile().insert(row);
    }
    bump_config_version(ctx);
}

fn default_avatar_fx() -> AvatarFx {
    AvatarFx {
        profile: "default".to_string(),
        crystal_palette: "#9ff0ff,#8fa8ff,#d99cff,#ffe7b0".to_string(),
        crystal_speed: 0.08,
        crystal_strength: 0.55,
        crystal_facets: 5.0,
        crystal_sparkle: 0.04,
        trail_enabled: true,
        trail_chars: ".,:;'`".to_string(),
        trail_color: "#8a6bff".to_string(),
        trail_rim: "#efe6ff".to_string(),
        trail_lifetime: 0.8,
        trail_spacing: 0.22,
        trail_size: 0.24,
        trail_spread: 0.6,
        trail_jitter: 0.12,
        lean_amount: 0.18,
        stretch_amount: 0.12,
        feel_smoothing: 0.12,
    }
}

/// Replaces the avatar look of a profile with a full row; bumps the config version
/// so a running game re-applies it. Pass every column in table order.
#[spacetimedb::reducer]
pub fn upsert_avatar_fx(ctx: &ReducerContext, row: AvatarFx) {
    if ctx.db.avatar_fx().profile().find(&row.profile).is_some() {
        ctx.db.avatar_fx().profile().update(row);
    } else {
        ctx.db.avatar_fx().insert(row);
    }
    bump_config_version(ctx);
}
