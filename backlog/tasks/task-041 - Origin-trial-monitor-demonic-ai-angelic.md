---
id: TASK-041
title: Origin trial monitor (demonic, ai, angelic)
status: Done
assignee:
  - '@claude'
created_date: '2026-11-02T06:43:00Z'
updated_date: '2026-11-02T08:22:00Z'
labels:
  - narrator
milestone: m-1
dependencies:
  - TASK-039
documentation:
  - docs/game_design.md
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Draft from task-016. Gameplay tests that disprove a narrator claim: survive high erosion and leave corruption (demonic), choose become one and survive 60 s (ai), stand idle 20 s far from light (angelic).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Each trial fires origin_trial_passed only while armed and its nature is alive; thresholds from config
- [x] #2 At most one strike per run, saved immediately
- [x] #3 A headless test covers one pass and one non-pass case per trial
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. OriginTrialMonitor node (scripts/origin) listening to existing signals; trial params from OriginTrial resources scaled by ledger.trial_scale. 2. Wire in build_main_scene. 3. tools/test_origin_trials.gd. 4. Validate, docs/architecture.md.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented scripts/origin/origin_trial_monitor.gd (OriginTrialMonitor node under Main, after HazardMonitor, wired in tools/build_main_scene.gd with exported refs ledger/run_manager/player/map_loader). OriginTrial got erosion_fraction (0.7, set in tools/build_origin.gd; trial_demonic.tres rebuilt). Evidence: tools/test_origin_trials.gd PASS headless (demonic/ai/angelic pass + non-pass cases, unarmed, struck, one strike per run with disk check, recant scaling, alien dormant). All tools/test_*.gd PASS; boot --quit-after 60 = 0 ERROR lines; build_origin idempotent (md5 of resources equal); build_main_scene structure stable but node unique_ids are random per build (pre-existing). --check-only on the monitor reports 'Identifier not found: SignalBus' like the existing ledger (autoload not visible to standalone check); the boot and tests compile it. Decisions: scale applies to seconds only (distance/erosion fraction unscaled so small maps stay feasible); ai/angelic timers start from the choice/idle even if the claim arrives later (claim_ai_one plays on the same event) but tick only while armed; demonic restarts survive time if erosion rises again; a trial reports once per run (a cap-refused one stays armed for next run); process is off unless a timer is running.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
OriginTrialMonitor (under Main) evaluates the demonic (survive high erosion then stay out of corruption 15 s), ai (choose the single form and survive 60 s) and angelic (idle 20 s at least 6 cells from any light) trials only while armed and alive, and emits origin_trial_passed; the ledger strikes at most once per run and saves immediately. Seconds scale with trial_scale after recants. Signal-driven, processing only while a timer can tick. Alien stays dormant (task-045). Validator PASS; tools/test_origin_trials.gd covers pass and non-pass per trial. Note: trials only get armed once the narrator plays the claims (task-042).
<!-- SECTION:FINAL_SUMMARY:END -->
