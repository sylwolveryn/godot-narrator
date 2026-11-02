# Narration Beats: M1 "Awakening Run"

Content spec for the M1 narrator. Implements the `NarrationBeat` fields in `docs/architecture.md` (Narrator), plus three additions: `min_deaths`, `mood`, and the origin stances `supports`, `contradicts`, `role`. All timings below are default values. They live in the narrator config `.tres`, not in code.

## Rules

### Events (SignalBus names)
| Event | Fires when |
|---|---|
| `run_started` | The intro wave settles and the character is visible. Fires once per run. |
| `first_move` | The first movement of the run. On run 1 this is also the moment input is discovered. |
| `idle` | No movement for `idle_seconds` (default 8 s). Fires at most once per run. |
| `wall_revealed` | The first wall of the run enters the reveal radius. Remembered walls count. |
| `item_revealed` | The first item of the run is revealed. |
| `spikes_revealed` | The first spike tile of the run is revealed. |
| `corruption_entered` | The character first enters a corrupting-glyph area this run. |
| `erosion_high` | Erosion first crosses `erosion_high_threshold` this run (default 70%). |
| `died_spikes` | Death by spikes. The beat plays over the death/restart transition. |
| `died_corruption` | Death by corruption. The beat plays over the death/restart transition. |

TIME beats count seconds from `run_started`. They are skipped if the run has already ended.

### Eligibility
A beat is eligible when all of these are true:
- Its trigger matches.
- `run_count >= min_run`.
- `run_count <= max_run`, or `max_run` is none.
- `death_count >= min_deaths`.
- It is not already in `heard_beats` (when `once` is true).

A beat is marked heard only once it starts displaying. A beat that gets dropped stays eligible.

### Priority (one beat per trigger)
1. **Within one event, play the ladder in order.** Pick the unheard eligible beat with the lowest `min_run`. If two tie, take the earlier one in the table. This means a late first encounter still gets the cryptic line first, and the story never skips a rung.
2. **Across simultaneous triggers, use the class order.** Highest priority first:
   - `died_*`
   - `erosion_high`
   - `corruption_entered`, `spikes_revealed`
   - `item_revealed`, `wall_revealed`
   - `run_started`, `first_move`
   - `idle`, TIME

### Display cap
- Only one beat is on screen at a time. Each beat shows for `beat_hold_seconds` (default 3.5 s), then a morph-in/out, then at least `beat_gap_seconds` (default 4 s) of silence.
- The queue holds one beat. A queued beat is dropped after `queue_ttl_seconds` (default 5 s). A newer beat of a higher class replaces a queued beat of a lower class.
- `died_*` beats preempt: the current beat dissolves immediately.
- `run_started` beats are exempt from `queue_ttl_seconds` (config `ttl_exempt_events`); a higher-class beat can still replace one, which then re-queues instead of dropping. A new run also cuts any remaining post-beat gap (a beat still on screen finishes normally), so the run-start line is never lost behind a death beat.

### Tone curve
- Run 1: fragments of 1 to 4 words, with no "you".
- Runs 2 and 3: "you" appears, along with one concrete image.
- Run 4: the narrator admits it is unreliable.
- Run 5 and later: direct and personal. The narrator speaks about itself and about its relationship to the character.
- Every account the narrator gives is contradicted by another one somewhere in the list.

### SFX moods
| Mood | Sound |
|---|---|
| `hum` | Warm steady tone (neutral, waking). |
| `chime` | Bright, short, rising (recognition, angelic lean). |
| `static` | Noise burst or crackle (corruption, machine lean). |
| `low_drone` | Deep sustained tone (death, dread, demonic lean). |
| `pulse` | Slow rhythmic beeps (signal, distance, alien lean). |

### Origin tags (for M2 rule-outs)
`hero`, `villain`, `alien`, `ai`, `demonic`, `angelic`, `none`. A beat can hint at several origins. M2 decides what the tags do.

## Beats

| id | text | trigger | min_run | max_run | min_deaths | once | mood | origin tags |
|---|---|---|---|---|---|---|---|---|
| `wake_first` | ...a shape. Waking. | EVENT `run_started` | 1 | 1 | 0 | true | hum | none |
| `move_first` | So. It moves. | EVENT `first_move` | 1 | 1 | 0 | true | chime | none |
| `idle_still` | Still. As it was kept. | EVENT `idle` | 1 | none | 0 | true | low_drone | villain, demonic |
| `wall_edges` | Edges. Always edges. | EVENT `wall_revealed` | 1 | none | 0 | true | hum | none |
| `item_not_yet` | Not yours. Not yet. | EVENT `item_revealed` | 1 | none | 0 | true | chime | none |
| `spikes_teeth` | Teeth. | EVENT `spikes_revealed` | 1 | none | 0 | true | static | none |
| `corrupt_knows` | It knows the shape. | EVENT `corruption_entered` | 1 | none | 0 | true | static | demonic, ai |
| `erosion_again` | Coming apart. Again. | EVENT `erosion_high` | 1 | none | 0 | true | static | ai |
| `death_spikes_down` | Down. | EVENT `died_spikes` | 1 | none | 0 | true | low_drone | none |
| `death_corrupt_scatter` | Scattered. Gathering. | EVENT `died_corruption` | 1 | none | 0 | true | static | ai |
| `start_came_back` | Again. You came back. | EVENT `run_started` | 2 | 2 | 1 | true | hum | angelic, ai |
| `spikes_for_your_kind` | They built these for your kind. | EVENT `spikes_revealed` | 2 | none | 1 | true | low_drone | alien, villain |
| `corrupt_after_war` | Static. Like after the war. | EVENT `corruption_entered` | 2 | none | 1 | true | static | ai |
| `death_spikes_willing` | You fell for them once. Willingly. | EVENT `died_spikes` | 2 | none | 1 | true | chime | hero, angelic |
| `start_saviour` | Third waking. Some called you saviour. | EVENT `run_started` | 3 | 3 | 2 | true | chime | hero |
| `item_across_stars` | You carried things like this. Across stars. | EVENT `item_revealed` | 3 | none | 2 | true | pulse | alien |
| `idle_burned` | Rest, then. You burned so many. | EVENT `idle` | 3 | none | 2 | true | low_drone | villain, demonic |
| `death_corrupt_halo` | The halo slips. It always slipped. | EVENT `died_corruption` | 3 | none | 2 | true | low_drone | angelic, demonic |
| `time_counting_signals` | Someone out there still counts your signals. | TIME 60 s | 3 | none | 2 | true | pulse | alien, ai |
| `start_invented_voice` | I remember your voice. Or I invented it. | EVENT `run_started` | 4 | 4 | 3 | true | hum | none |
| `wall_keep_them_out` | You built walls like these. To keep them out. | EVENT `wall_revealed` | 4 | none | 3 | true | hum | hero, villain |
| `erosion_true_name` | Hold on. Don't let it read your name. | EVENT `erosion_high` | 4 | none | 3 | true | low_drone | demonic |
| `start_hero_lied` | I told you you were a hero. Maybe I lied. | EVENT `run_started` | 5 | 5 | 4 | true | hum | hero, villain |
| `death_spikes_watch` | I'm sorry. I watch every time. | EVENT `died_spikes` | 5 | none | 4 | true | hum | none |
| `start_bright_or_crashed` | You fell from somewhere bright. Or you crashed. | EVENT `run_started` | 6 | 6 | 5 | true | chime | angelic, alien |
| `start_chose_return` | Whatever you were, you chose to come back. | EVENT `run_started` | 7 | none | 6 | true | hum | none |

26 beats in total. Every origin tag appears in at least three beats.

## Design notes
- **Death floor.** In M1, `run_count = death_count + 1`. `min_deaths` is set to match so the table stays consistent if a non-death run end is added later (for example, narrative choices).
- **Start beats.** The `run_started` beats are pinned to one run each (`max_run` = `min_run`), so the start of every run always gets a fresh line. Run 7 and later play `start_chose_return` once, then stay silent at start. That silence is intentional: content beyond M1 fills it.
- **Event ladders.** Event beats have no `max_run`. A missed hazard line waits for the first encounter instead of being lost.
- **Contradictions.** Contradicting pairs are deliberate:
  - `idle_still` (kept/bound) vs `start_came_back` (returned by choice).
  - `death_spikes_willing` (sacrifice) vs `idle_burned` (destroyer).
  - `corrupt_after_war` (machine) vs `erosion_true_name` (demonic name).
  - `start_bright_or_crashed` contradicts itself.
- **No tutorial text.** No beat names a control, a key, or a goal. `item_not_yet` is the only nod to items being unusable in M1, and it reads as story, not as a rule.
