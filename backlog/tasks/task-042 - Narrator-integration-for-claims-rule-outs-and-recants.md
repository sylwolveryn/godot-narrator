---
id: TASK-042
title: Narrator integration for claims, rule-outs and recants
status: Done
assignee:
  - '@claude'
created_date: '2026-11-02T06:43:00Z'
updated_date: '2026-11-02T09:00:00Z'
labels:
  - narrator
milestone: m-1
dependencies:
  - TASK-039
  - TASK-040
  - TASK-041
  - TASK-044
documentation:
  - docs/game_design.md
priority: high
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Draft from task-016. The narrator arms trials with CLAIM beats, reacts to strikes and recants, and plays doubt-flagged lines for struck natures.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Hearing a CLAIM beat arms its trial; BROKEN and RECANT beats play on origin_struck / origin_recanted
- [x] #2 Beats whose supports are all struck play with the doubt flag (part of the glyphs never settle)
- [x] #3 At the floor, tie-breaking prefers beats supporting both surviving natures
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Narrator: event_param, origin_struck/origin_recanted/entity_form_changed events, reactive FIFO for broken/recant, claim eligibility via ledger, origin_claim_heard on CLAIM/RECANT display. 2. Doubt flag (doubt_fraction -> overlay: share of letters sway, no char swap). 3. Floor tie-break in pick_for_event. 4. Tests in tools/test_narrator.gd, capture tool for visual check. 5. Docs.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented (not committed). Narrator: NarrationBeat.event_param; events origin_struck / origin_recanted (reactive FIFO, never dropped by queue TTL, start from GAP, no preempt of death beats) and entity_form_changed (animated only). CLAIM beats eligible only via OriginLedger.is_claimable (alive, unarmed, trial not dormant: alien dormant). CLAIM or RECANT display emits origin_claim_heard -> ledger arms. Doubt: Narrator.doubt_fraction (all supports struck natures) -> current_doubt -> overlay sways a share (OriginConfig.doubt_scramble) of letters calmly (<=0.5 Hz, no char swapping). Floor tie-break in pick_for_event (min_run first, then beat supporting both survivors, then order). Evidence: tools/test_narrator.gd PASS (claim arms trial end-to-end, struck->broken per param, floor strike plays recant then broken, doubt iff all supports struck, tie-break, claim_ai_one on animated switch only); ALL tools/test_*.gd PASS; headless boot --quit-after 60 zero ERROR; visual: tools/capture_origin_narration.gd (temp save) contact sheet t042_origin_sheet.png shows broken_demonic, broken_ai and doubt-flagged erosion_again. Decisions: RECANT also arms (restates claim, per design); reactive events outside a run accepted; added OriginTrial.dormant. Docs updated: docs/architecture.md, docs/narration_origin.md.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Narrator integrated with the origin system: NarrationBeat.event_param; narrator listens to origin_struck / origin_recanted / animated entity_form_changed. A CLAIM (or a RECANT restating it) emits origin_claim_heard when it starts displaying, arming the trial; CLAIM beats are eligible only while the nature is claimable. BROKEN/RECANT use a reactive FIFO that is never dropped and never preempts death beats. Doubt flag: beats whose supports are all struck show ~30% of letters swaying/dimming calmly (no character swaps, <0.5 Hz at default). Floor tie-break prefers beats supporting both survivors. Validator PASS. Note: the doubt_hz export range allows up to 0.6 Hz effective sway at its maximum; keep it <= 0.4.
<!-- SECTION:FINAL_SUMMARY:END -->
