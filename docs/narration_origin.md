# Narration Beats: Origin Claims, Broken and Recant Lines

**Status: approved by the user on 2026-11-02** (task-044). Change from draft: `claim_ai_one` triggers on the form switch (`entity_form_changed`), not `died_corruption`.

> 2026-11-08 (task-049): event names are now the DB `event_def` ids (`CORRUPTION_ENTERED`, `TRANSFORMED`, `IDLE_FOR_SHORT`, ...); the lines below use them. Line texts also live in `narration/event/<EVENT>_EN_GB.json`.

**Implementation status (task-042/044, 2026-11-02):** the 14 lines are in `data/narration/origin_beats.json` (text copied from the table below, checked by `tools/test_narrator.gd`); the narrator integration and the strict lint are in. The text here is unchanged and remains the source of truth.

Content for the Origin Contradiction and Rule-Out System (`docs/game_design.md`, section "Origin Contradiction and Rule-Out System"). It follows the format and rules of `docs/narration_m1.md`: the same events, eligibility, ladder priority, display cap, tone curve and moods. All numbers are defaults that live in the narrator and origin config `.tres` files.

## Rules specific to these beats

### Roles
| Role | What it does | Eligible when |
|---|---|---|
| `CLAIM` | A taunt of the form "if you were X, you could never Y". Hearing it arms that nature's trial (`origin_claim_heard`). | Its trigger matches, the run gates pass, and its nature is alive and unarmed. |
| `BROKEN` | Plays at once when a trial passes and the nature is struck. Unsettled, never triumphant. | EVENT `ORIGIN_STRUCK` with matching `event_param`. |
| `RECANT` | Plays when the floor rule restores a nature. The narrator takes it back, restates the claim obliquely and the trial re-arms at a scaled threshold. | EVENT `ORIGIN_RECANTED` with matching `event_param`. |
| `STORY` | Normal beat (the two contradiction lines below). | As in `narration_m1.md`. |

### Gating
- **Claims arrive with the menu and the ledger:** `min_run` 4, `min_deaths` 3 (design section 5).
- Claims are `once = true`. A recant re-arms the trial itself, so the claim does not need to replay.
- `BROKEN` and `RECANT` are `once = false`: the floor rule can strike and recant the same nature more than once (ping-pong). Their `min_run` is 4 only as a safety gate; in practice their events cannot fire earlier, because no trial is armed before a claim is heard.
- `BROKEN` and `RECANT` belong to the `died_*` priority class (they react to something the player just did and must not be dropped by the queue TTL). They do not preempt a `died_*` beat already on screen; they queue behind it.
- **Alien set ships dormant.** The alien claim stays ineligible until the OBJECT_MOVED trial exists (task G, entity pushing). Its broken and recant lines therefore cannot fire either.

### Mood
Broken and recant lines take the mood of their nature, as the design asks: `demonic` = `low_drone`, `ai` = `static`, `angelic` = `chime`, `alien` = `pulse`.

### Stances
- A `CLAIM` **supports** its nature (the narrator leans on it while taunting).
- A `BROKEN` line **contradicts** its nature and supports nothing. Its text always leaves a second reading open.
- A `RECANT` line **supports** its nature again.
- Deeds (`hero`, `villain`) are never touched by these lines.

## Beats

| id | text | role | trigger | event_param | min_run | max_run | min_deaths | once | mood | supports | contradicts |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `claim_demonic_name` | Once the static reads your name, it never lets go. | CLAIM | EVENT `CORRUPTION_ENTERED` | - | 4 | none | 3 | true | low_drone | demonic | - |
| `claim_ai_one` | Built things never choose to be one. Not for long. | CLAIM | EVENT `TRANSFORMED` | - | 4 | none | 3 | true | static | ai | - |
| `claim_angelic_dark` | Fallen from the light, you could never rest in the dark. | CLAIM | EVENT `IDLE_FOR_SHORT` | - | 4 | none | 3 | true | chime | angelic | - |
| `claim_alien_weight` | If you came from the stars, nothing here would move for you. | CLAIM | EVENT `ITEM_REVEALED` (dormant until task G) | - | 4 | none | 3 | true | pulse | alien | - |
| `broken_demonic` | ...It let you go. Then that was not your name. | BROKEN | EVENT `ORIGIN_STRUCK` | demonic | 4 | none | 3 | false | low_drone | - | demonic |
| `broken_ai` | ...Still one. Then not built. Or built to lie. | BROKEN | EVENT `ORIGIN_STRUCK` | ai | 4 | none | 3 | false | static | - | ai |
| `broken_angelic` | ...You rested there. Then not the light. Not yet. | BROKEN | EVENT `ORIGIN_STRUCK` | angelic | 4 | none | 3 | false | chime | - | angelic |
| `broken_alien` | ...It moved for you. Then not the stars. | BROKEN | EVENT `ORIGIN_STRUCK` | alien | 4 | none | 3 | false | pulse | - | alien |
| `recant_demonic` | I was too sure. Some names hide longer in the static. | RECANT | EVENT `ORIGIN_RECANTED` | demonic | 4 | none | 3 | false | low_drone | demonic | - |
| `recant_ai` | I was too sure. Machines can wait. Longer than that. | RECANT | EVENT `ORIGIN_RECANTED` | ai | 4 | none | 3 | false | static | ai | - |
| `recant_angelic` | I spoke too soon. Light can rest. Just never for long. | RECANT | EVENT `ORIGIN_RECANTED` | angelic | 4 | none | 3 | false | chime | angelic | - |
| `recant_alien` | No. I was too sure. The stars come back. | RECANT | EVENT `ORIGIN_RECANTED` | alien | 4 | none | 3 | false | pulse | alien | - |
| `item_carried_down` | Not across stars. I watched something carry you down. | STORY | EVENT `ITEM_REVEALED` | - | 6 | none | 5 | true | chime | angelic | alien |
| `time_hull_burn` | There was no heaven. I saw the hull burn. | STORY | TIME 90 s | - | 5 | none | 4 | true | pulse | alien | angelic |

14 lines: 4 claims, 4 broken, 4 recant, 2 contradiction lines.

## Design notes

### How each claim hints at its trial
Claims never name a control, a key, a menu entry or a goal. Each one states a "never" that the player can only disprove by doing the trial.
- **Demonic** (`claim_demonic_name`): "reads your name" ties back to `erosion_true_name` ("Don't let it read your name"), so high erosion is the reading. "Never lets go" is the falsifier: get read, then get out and stay out. Placed on `corruption_entered` so it can be heard before `erosion_high` in the same run and the trial can pass in that run.
- **AI** (`claim_ai_one`): "choose to be one" echoes the menu's "become one" wording without naming the menu. "Not for long" points at the survival time. Plays when the player switches form in the menu (user decision), so the claim lands at the moment the trial can begin.
- **Angelic** (`claim_angelic_dark`): "rest" is idle, "the dark" is distance from light sources. Placed on `idle` so it lands at the moment the player is already standing still, usually in a lit place.
- **Alien** (`claim_alien_weight`): "nothing here would move for you" points at moving an object. Placed on `item_revealed` so an object is in view when it plays, and it follows `item_across_stars` (alien, run 3) on the same ladder.

### How recants hint at the scaled threshold
The recant re-arms the trial at `retry_scale` (1.5x) per previous strike. Demonic ("hide longer"), ai ("Longer than that") and angelic ("never for long") hint that the old proof was too short. Alien has no time threshold, so its recant is the design's own example line.

### Why broken and recant lines stay ambiguous
- `broken_demonic`: either it was never demonic, or the static read the wrong name.
- `broken_ai`: "Or built to lie" keeps the machine reading alive inside its own refutation.
- `broken_angelic`: "Not yet" leaves room for a fall still in progress.
- `broken_alien`: the design's example. It denies the stars, not the "elsewhere".
- Recants only say "I was too sure". None of them claims the nature is true, only that it is possible again.

### The two contradiction lines
The design notes that no current beat contradicts `alien` or `angelic`. The two new lines contradict one each and support the other, so the pair also contradicts each other, and neither nature gains ground overall.
- `item_carried_down` contradicts `alien` (and `item_across_stars` directly: "Not across stars") and supports `angelic` ("carry you down"). It sits on the `item_revealed` ladder after the alien claim.
- `time_hull_burn` contradicts `angelic` ("no heaven") and supports `alien` (a hull, a crash). It answers `start_bright_or_crashed` by picking "crashed", and is itself answered by `item_carried_down`.
- Both are run 5+ lines, so they use "I" (the narrator speaks about itself, per the tone curve).

### Balance after these lines (supports / contradicts, story beats only)
| Nature | Supports (M1 + new story) | Contradicts (M1 + new story) |
|---|---|---|
| `ai` | 6 | 1 (`erosion_true_name`) |
| `demonic` | 5 | 2 (`start_came_back`, `corrupt_after_war`) |
| `alien` | 5 | 1 (`item_carried_down`) |
| `angelic` | 5 | 1 (`time_hull_burn`) |

Counting the claim, broken and recant lines adds one support (claim), one support (recant) and one contradiction (broken) to every nature equally, so they do not shift the balance. Every nature now has at least one supporting and one contradicting beat, which is what the task B lint checks.

### Ladder and collision checks
- `corruption_entered`: `corrupt_knows` (1), `corrupt_after_war` (2), `claim_demonic_name` (4).
- `died_corruption`: `death_corrupt_scatter` (1), `death_corrupt_halo` (3).
- `idle`: `idle_still` (1), `idle_burned` (3), `claim_angelic_dark` (4). Idle fires once per run, so a player who missed earlier idle beats hears the claim later. This is acceptable: the trial cannot be passed by accident before the claim.
- `item_revealed`: `item_not_yet` (1), `item_across_stars` (3), `claim_alien_weight` (4, dormant and skipped), `item_carried_down` (6).
- TIME 90 s is a new TIME trigger. It does not collide with `time_counting_signals` (60 s).

### Open points for the user
- `claim_ai_one` fires on `entity_form_changed` (user decision 2026-11-02); the narrator subscribes to that event in task-042.
- The text "be one" depends on the menu entry actually being labelled "become one". If the label changes, the claim should change with it.
- These lines live in this M2 file rather than in `docs/narration_m1.md`. Task F allows either.
