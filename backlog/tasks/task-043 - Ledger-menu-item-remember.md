---
id: TASK-043
title: Ledger menu item "remember"
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-02T06:43:00Z'
updated_date: '2026-11-02T09:01:00Z'
labels:
  - narrator
milestone: m-1
dependencies:
  - TASK-039
  - TASK-042
documentation:
  - docs/game_design.md
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Draft from task-016. A menu item that shows the origin ledger as a row of sigils built from surrounding glyphs, without pausing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Struck sigils stay on the floor, recanted ones show a crack, deed sigils never settle
- [ ] #2 Offered only after a claim has been heard; stays within the menu single draw call
- [ ] #3 User visual check
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add remember MenuItemDef (action remember) + builder; 2. MenuController offers it only after a claim is heard; 3. Glyph view renders ledger sigil row in the same MultiMesh with per-state flags (alive/struck/recanted/deed); 4. Tests + capture; 5. docs
<!-- SECTION:PLAN:END -->
