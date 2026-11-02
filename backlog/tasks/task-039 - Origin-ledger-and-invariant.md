---
id: TASK-039
title: Origin ledger and invariant
status: Done
assignee:
  - '@claude'
created_date: '2026-11-02T06:43:00Z'
updated_date: '2026-11-02T08:11:00Z'
labels:
  - narrator
milestone: m-1
dependencies: []
documentation:
  - docs/game_design.md
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Draft from task-016 (pending user review of the origin rule-out design). The ledger is the single owner of struck/recanted origin natures and enforces the guarantee that at least 2 of the 4 natures always remain and deeds are never struck.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 OriginHypothesis, OriginTrial and OriginConfig resources exist, built by a tools/ builder; 4 nature and 2 deed .tres load
- [x] #2 OriginLedger is the only writer of struck_natures; a headless test of 1000 random strike sequences keeps >= 2 natures alive and never strikes a deed
- [x] #3 A save with 3 struck natures is repaired to 2 (newest strike recanted) with a logged warning
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. OriginHypothesis/OriginTrial/OriginConfig resources + tools/build_origin.gd (4 nature + 2 deed .tres, separate trial .tres, origin_config.tres).
2. PersistentProgress fields (struck_natures, armed_trials, strike_counts, last_strike_run); SaveService type-sanitizes them, adds commit_progress() and progress_loaded.
3. SignalBus origin_* signals; OriginLedger node (sole writer, floor rule, per-run cap, load repair); wire in build_main_scene.
4. tools/test_origin_ledger.gd: 1000 random sequences, repair, persistence round trip.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented: scripts/origin/{origin_trial,origin_hypothesis,origin_config,origin_ledger}.gd; tools/build_origin.gd (4 nature + 2 deed .tres, trial_<nature>.tres, origin_config.tres; idempotent, md5 of all resources identical on rebuild); PersistentProgress fields; SaveService type-sanitizes them + commit_progress()/progress_loaded; SignalBus origin_* signals; OriginLedger wired in build_main_scene after SaveService.
Evidence: tools/test_origin_ledger.gd PASS headless (14000 random ops over 1000 sequences incl. deeds/unknown ids: >=2 natures alive, no deed struck, no dups, floor recants exercised; repair of 3 and 4 struck (newest recanted, repair_log + push_warning, repaired save written), unknown ids/deeds dropped; persistence round trip incl. per-run cap after reload; static scan proves no other script touches the state fields). All 16 tools/test_*.gd PASS; boot --quit-after 60: 0 ERROR lines. Expected 'ERROR: min_alive_nature 1 is below...' appears only in the clamp test (designed logged error).
Decisions: run_index = persistent PersistentProgress.run_count (RunManager run_index resets per launch). Recant of a nature leaves its trial unarmed until origin_claim_heard. Trials stored as separate .tres (embedded sub-resource ids are random = non-idempotent). Sigils * # ^ + ! x and labels are placeholders for task-043. Claim/broken/recant beat ids are conventional (claim_<id> ...) and dangle until task-044. max_strikes_per_run > 1 undercounts after a reload (only last_strike_run persisted, as designed).

Validator fix: ledger-only-writer scan in tools/test_origin_ledger.gd now covers res://scripts/ only (allow-list: ledger, persistent_progress, save_service); tools/test_save.gd no longer flagged. Docs: origin_tags wording replaced in docs/narration_m1.md (line 3) and docs/game_design.md (208, 263, 309). Re-run: all 16 tools/test_*.gd PASS headless, boot --quit-after 60 = 0 error lines.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
OriginLedger (child of Main) is the only runtime writer of struck_natures / armed_trials / strike_counts / last_strike_run (persisted, type-sanitized on load, invariant repaired by the ledger). Floor rule: >= 2 of 4 natures always alive, deeds never struck; a strike that would break the floor recants the oldest strike first; strike_counts drive trial_scale for harder re-trials. Resources built by tools/build_origin.gd. tools/test_origin_ledger.gd: 1000 random sequences, save repair, persistence. Validator PASS after a scan-guard fix.
<!-- SECTION:FINAL_SUMMARY:END -->
