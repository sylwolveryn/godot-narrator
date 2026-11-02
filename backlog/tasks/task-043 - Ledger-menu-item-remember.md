---
id: TASK-043
title: Ledger menu item "remember"
status: Done
assignee:
  - '@claude'
created_date: '2026-11-02T06:43:00Z'
updated_date: '2026-11-02T10:16:00Z'
labels:
  - narrator
milestone: m-1
dependencies:
  - TASK-039
  - TASK-042
documentation:
  - docs/game_design.md
priority: medium
ordinal: 46000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Draft from task-016. A menu item that shows the origin ledger as a row of sigils built from surrounding glyphs, without pausing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Struck sigils stay on the floor, recanted ones show a crack, deed sigils never settle
- [x] #2 Offered only after a claim has been heard; stays within the menu single draw call
- [x] #3 User visual check
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add remember MenuItemDef (action remember) + builder; 2. MenuController offers it only after a claim is heard; 3. Glyph view renders ledger sigil row in the same MultiMesh with per-state flags (alive/struck/recanted/deed); 4. Tests + capture; 5. docs
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented: MenuItemDef remember (requires_claim, built by tools/build_menu.gd); OriginLedger.any_claim_heard(); MenuController.ledger (read-only), show_ledger/back_to_list/ledger_entries, SignalBus.menu_ledger_shown; MenuGlyphView sigil row in the same MultiMesh (kinds 4 alive,5 struck,6 recanted,7 deed) + glyph_menu.gdshader (struck pinned on floor dim, recanted split-crack, deed slow calm drift, never settles); MenuConfig Ledger group. Evidence: tools/test_menu.gd PASS (absent before claim, present after, state->kind mapping, single MultiMesh, no pause, back/Tab); all 16 tools/test_*.gd PASS; headless boot 0 ERROR; build_menu idempotent. Contact sheet: scratchpad/t043_remember.png (capture tools/capture_remember.gd). User visual check pending.

Implementation validated (combined validator PASS with task-045) and committed. Waiting for the user visual check (AC3): sigil size/brightness and deed drift, tunable in MenuConfig Ledger group.
<!-- SECTION:NOTES:END -->
