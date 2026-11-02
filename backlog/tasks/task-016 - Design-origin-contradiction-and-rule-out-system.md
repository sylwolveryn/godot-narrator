---
id: TASK-016
title: 'Design: origin contradiction and rule-out system'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T15:42:00Z'
updated_date: '2026-11-02T06:43:00Z'
labels:
  - narrator
milestone: m-1
dependencies: []
documentation:
  - docs/game_design.md
priority: high
type: spike
ordinal: 16000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The character origin must never have a single answer: narration contradicts itself (hero/villain, alien, post-war AI, demonic, angelic), yet players must be able to rule some options out through gameplay. How beats map to hypotheses and how rule-outs happen is undecided and shapes all narration content.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A design section in docs/game_design.md defines the origin hypotheses, how narration beats reference them, and how gameplay rules options out
- [x] #2 The design guarantees no run sequence can confirm a single origin
- [x] #3 Follow-up implementation tasks are created in Backlog
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
game-designer drafted the section "Origin Contradiction and Rule-Out System" in docs/game_design.md (status: draft for user review). Guarantee: at least 2 of 4 natures always open and deeds never struck; a rule-out that would break the floor recants the oldest strike first. Seven follow-ups created as Backlog drafts (M2). Waiting on user review before Done.
<!-- SECTION:NOTES:END -->
