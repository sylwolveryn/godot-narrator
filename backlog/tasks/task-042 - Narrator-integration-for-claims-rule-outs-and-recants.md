---
id: TASK-042
title: Narrator integration for claims, rule-outs and recants
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-02T06:43:00Z'
updated_date: '2026-11-02T08:40:00Z'
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
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Draft from task-016. The narrator arms trials with CLAIM beats, reacts to strikes and recants, and plays doubt-flagged lines for struck natures.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Hearing a CLAIM beat arms its trial; BROKEN and RECANT beats play on origin_struck / origin_recanted
- [ ] #2 Beats whose supports are all struck play with the doubt flag (part of the glyphs never settle)
- [ ] #3 At the floor, tie-breaking prefers beats supporting both surviving natures
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Narrator: event_param, origin_struck/origin_recanted/entity_form_changed events, reactive FIFO for broken/recant, claim eligibility via ledger, origin_claim_heard on CLAIM/RECANT display. 2. Doubt flag (doubt_fraction -> overlay: share of letters sway, no char swap). 3. Floor tie-break in pick_for_event. 4. Tests in tools/test_narrator.gd, capture tool for visual check. 5. Docs.
<!-- SECTION:PLAN:END -->
